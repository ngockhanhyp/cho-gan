(() => {
  let googleLibrary;
  function loadGoogle() {
    if (window.google?.accounts?.oauth2) return Promise.resolve();
    googleLibrary ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.onload = resolve;
      script.onerror = () => {
        googleLibrary = null;
        script.remove();
        reject(new Error('Google Identity is unavailable'));
      };
      document.head.append(script);
    });
    return googleLibrary;
  }

  async function googleToken(clientId, scope) {
    await loadGoogle();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Google sign-in timed out')), 120000);
      const complete = (callback, value) => {
        clearTimeout(timer);
        callback(value);
      };
      try {
        const client = google.accounts.oauth2.initTokenClient({
          client_id: clientId,
          scope,
          include_granted_scopes: false,
          callback: result => result.access_token
            ? complete(resolve, result.access_token)
            : complete(reject, new Error('Google authorization failed')),
          error_callback: error => complete(reject, new Error(error.type)),
        });
        client.requestAccessToken({prompt: 'select_account'});
      } catch (error) {
        complete(reject, error);
      }
    });
  }

  window.passyCreateOwnerSheet = async (clientId, title, rowsJson) => {
    const token = await googleToken(clientId, 'https://www.googleapis.com/auth/drive.file');
    const rows = JSON.parse(rowsJson).map(row => ({
      values: row.map(value => ({userEnteredValue: {stringValue: value}})),
    }));
    const response = await fetch(
      'https://sheets.googleapis.com/v4/spreadsheets?fields=spreadsheetId',
      {
        method: 'POST',
        headers: {Authorization: 'Bearer ' + token, 'Content-Type': 'application/json'},
        body: JSON.stringify({
          properties: {title},
          sheets: [{
            properties: {title: 'Passy', gridProperties: {
              rowCount: Math.max(100, rows.length),
              columnCount: Math.max(20, rows[0].values.length),
              frozenRowCount: 1,
            }},
            data: [{startRow: 0, startColumn: 0, rowData: rows}],
          }],
        }),
      },
    );
    if (!response.ok) throw new Error('Sheets API: ' + response.status);
    const {spreadsheetId} = await response.json();
    if (!/^[a-zA-Z0-9_-]+$/.test(spreadsheetId)) throw new Error('Invalid spreadsheet ID');
    return 'https://docs.google.com/spreadsheets/d/' + spreadsheetId + '/edit';
  };
  let excelLibrary;
  function loadExcel() {
    excelLibrary ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js';
      script.integrity = 'sha384-EnyY0/GSHQGSxSgMwaIPzSESbqoOLSexfnSMN2AP+39Ckmn92stwABZynq1JyzdT';
      script.crossOrigin = 'anonymous';
      script.onload = resolve;
      script.onerror = () => {
        excelLibrary = null;
        script.remove();
        reject(new Error('Excel reader failed to load'));
      };
      document.head.append(script);
    });
    return excelLibrary;
  }

  window.passyReadOwnerWorkbook = async () => {
    const file = await new Promise(resolve => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = '.xlsx,.csv';
      input.style.display = 'none';
      const finish = file => { input.remove(); resolve(file); };
      input.onchange = () => finish(input.files[0]);
      input.oncancel = () => finish(null);
      document.body.append(input);
      input.click();
    });
    if (!file) return '';
    if (file.size > 5 * 1024 * 1024) throw new Error('Workbook exceeds 5 MB');
    await loadExcel();
    const book = XLSX.read(await file.arrayBuffer(), {sheetRows: 52, sheets: 0});
    const sheet = book.Sheets[book.SheetNames[0]];
    if (!sheet?.['!ref']) return '[]';
    const bounds = XLSX.utils.decode_range(sheet['!ref']);
    if (bounds.e.c > 40 || XLSX.utils.decode_range(sheet['!fullref'] || sheet['!ref']).e.r > 50) {
      throw new Error('Workbook has more than 50 data rows or 41 columns');
    }
    const rows = [];
    for (let row = 0; row <= bounds.e.r; row++) {
      rows.push(Array.from({length: bounds.e.c + 1}, (_, column) => {
        const cell = sheet[XLSX.utils.encode_cell({r: row, c: column})];
        const formulaImage = cell?.f?.match(/^(?:_xlfn\.)?IMAGE\("([^"]+)"/i);
        return formulaImage?.[1] || cell?.l?.Target || cell?.v || (cell?.v === 0 ? 0 : '');
      }));
    }
    return JSON.stringify(rows);
  };

  window.passyReadOwnerSheet = async (clientId, url) => {
    const source = new URL(url);
    const id = source.hostname === 'docs.google.com' &&
      source.pathname.match(/^\/spreadsheets\/d\/([a-zA-Z0-9_-]+)(?:\/|$)/)?.[1];
    if (source.protocol !== 'https:' || !id) throw new Error('Invalid Google Sheet link');
    const token = await googleToken(clientId, 'https://www.googleapis.com/auth/spreadsheets.readonly');
    const headers = {Authorization: 'Bearer ' + token};
    const base = 'https://sheets.googleapis.com/v4/spreadsheets/' + id;
    const metadata = await fetch(base + '?fields=sheets.properties(sheetId,title,index)', {headers});
    if (!metadata.ok) throw new Error('No access to spreadsheet');
    const {sheets} = await metadata.json();
    const gid = new URLSearchParams(source.hash.slice(1)).get('gid') ?? source.searchParams.get('gid');
    const selected = gid === null ? sheets.find(sheet => sheet.properties.index === 0)
      : sheets.find(sheet => String(sheet.properties.sheetId) === gid);
    if (!selected) throw new Error('Sheet tab not found');
    const range = encodeURIComponent("'" + selected.properties.title.replaceAll("'", "''") + "'!A:AO");
    const data = await fetch(base + '/values/' + range + '?valueRenderOption=FORMULA', {headers});
    if (!data.ok) throw new Error('Cannot read sheet rows');
    const {values = []} = await data.json();
    if (values.length > 51) throw new Error('Sheet has more than 50 data rows');
    return JSON.stringify(values.map(row => row.map(cell => {
      const formula = typeof cell === 'string' && cell.match(/^=IMAGE\(\"([^"]+)"/i);
      return formula ? formula[1] : cell;
    })));
  };
})();

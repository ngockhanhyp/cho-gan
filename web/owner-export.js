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

  window.passyCreateOwnerSheet = async (clientId, title, rowsJson) => {
    await loadGoogle();
    const token = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Google sign-in timed out')), 120000);
      const complete = (callback, value) => {
        clearTimeout(timer);
        callback(value);
      };
      try {
        const client = google.accounts.oauth2.initTokenClient({
          client_id: clientId,
          scope: 'https://www.googleapis.com/auth/drive.file',
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
})();

uses Globals, Kitchensink, FormLayoutDemo, FormNonVisual,
     //semantic zoom demo
     FormZoom,
     //invoice demo
     InvoiceData, InvoiceStyles, FormInvoiceList,
     FormInvoiceDetail, FormInvoiceEditor, FormClientList,
     //home assist secure
     HASTypes, HASPermissions, HASData, HASStyles,
     FormLogin, FormShell,
     PageDashboard, PageCustomers, PageContractors, PageEnrollments,
     PageQuotes, PageBatches, PagePayments,
     PageCatalogue, PageReports, PageAuditLog,
     //bridge
     FormBridge,
     //noise
     FormNoise,
     //some more
     FormInputs,
     //database scenarios
     FormBooks,
     FormBooksRaw;

//create forms
Application.CreateForm('Kitchensink',   TKitchensink);
Application.CreateForm('FormLayoutDemo',TFormLayoutDemo);
Application.CreateForm('FormNonVisual', TFormNonVisual);

Application.CreateForm('InvoiceList',   TFormInvoiceList);
Application.CreateForm('InvoiceDetail', TFormInvoiceDetail);
Application.CreateForm('InvoiceEditor', TFormInvoiceEditor);
Application.CreateForm('ClientList',    TFormClientList);

Application.CreateForm('HASLogin',      TFormLogin);
Application.CreateForm('HASShell',      TFormShell);

Application.CreateForm('FormBridge',    TFormBridge);
Application.CreateForm('FormNoise',     TFormNoise);

Application.CreateForm('FormInputs',    TFormInputs);
Application.CreateForm('SemanticZoom',  TFormZoom);

Application.CreateForm('FormBooks',     TFormBooks);
Application.CreateForm('FormBooksRaw',  TFormBooksRaw);

//Apply theme (light or dark)
ApplyTheme;

//show initial form
//Application.GoToForm('Kitchensink');
//Application.GoToForm('InvoiceList');
//Application.GoToForm('HASLogin');
//Application.GoToForm('SemanticZoom');
//Application.GoToForm('FormBridge');
//Application.GoToForm('FormNoise');
//Application.GoToForm('FormInputs');
//Application.GoToForm('FormSQL1');
Application.GoToForm('FormBooks');
//Application.GoToForm('FormBooksRaw');

///////////////////////////////////////////////////////////////
// or for node : just 1 line
//
//uses NodeHello;  or
//uses uses NodeHttpServer;
//
//and execute with node index.js
//
///////////////////////////////////////////////////////////////

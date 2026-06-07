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
     FormBooksRaw,
     FormCodecs,
     //FormChatStreamTest,
     FormChatStreamReal,
     FormChatStreamDemo,
     FormLLM,
     //Edam2
     MyFormEDAM2,
//
// apply theme. reverts to somewhat boring defaults when omitted
//
     ThemeStyles;

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

Application.CreateForm('FormCodecs',    TFormCodecs);

//Application.CreateForm('FormChatStream',TFormChatStream);
Application.CreateForm('FormLLM',       TFormLLM);
Application.CreateForm('FormChatLLM',   TFormChatLLM);

Application.CreateForm('FormEdam2',     TFormEdam2);

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
//Application.GoToForm('FormBooks');
//Application.GoToForm('FormBooksRaw');
////Application.GoToForm('FormChatStream');
//Application.GoToForm('FormChatLLM');
//Application.GoToForm('FormLLM');
Application.GoToForm('FormEdam2');

///////////////////////////////////////////////////////////////
// or for node : just 1 line
//
//uses NodeHello;  or
//uses uses NodeHttpServer;
//
//and execute with node index.js
//
///////////////////////////////////////////////////////////////

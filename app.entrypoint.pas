uses Globals, Kitchensink, FormLayoutDemo, FormNonVisual,
     //invoice demo
     InvoiceData, InvoiceStyles, FormInvoiceList, 
     FormInvoiceDetail, FormInvoiceEditor, FormClientList;

//create forms
Application.CreateForm('Kitchensink',TKitchensink);
Application.CreateForm('FormLayoutDemo',TFormLayoutDemo);
Application.CreateForm('FormNonVisual',  TFormNonVisual);

Application.CreateForm('InvoiceList',   TFormInvoiceList);
Application.CreateForm('InvoiceDetail', TFormInvoiceDetail);
Application.CreateForm('InvoiceEditor', TFormInvoiceEditor);
Application.CreateForm('ClientList',    TFormClientList);

//show initial form
Application.GoToForm('Kitchensink');
//Application.GoToForm('InvoiceList');

///////////////////////////////////////////////////////////////
// or for node : just 1 line
//
//uses NodeHello;  or
//uses uses NodeHttpServer;
//
//and execute with node index.js
//
///////////////////////////////////////////////////////////////

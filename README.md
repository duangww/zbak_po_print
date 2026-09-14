## Application Details

|                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------- |
| **Generation Date and Time**<br>Mon Sep 14 2026 09:25:16 GMT+0800 (Hong Kong Standard Time)                                           |
| **App Generator**<br>SAP Fiori Application Generator                                                                                  |
| **App Generator Version**<br>1.32.0                                                                                                   |
| **Generation Platform**<br>Visual Studio Code                                                                                         |
| **Template Used**<br>List Report Page V4                                                                                              |
| **Service Type**<br>OData URL                                                                                                         |
| **Service URL**<br>https://sapbkd-app.bak.com.cn:44300/sap/opu/odata4/sap/zui_mm_r002_o4/srvd/sap/zui_mm_r002/0001/                   |
| **Module Name**<br>zbak_po_print                                                                                                      |
| **Application Title**<br>采购订单打印                                                                                                       |
| **Namespace**<br>                                                                                                                     |
| **UI5 Theme**<br>sap_horizon                                                                                                          |
| **UI5 Version**<br>1.120.23                                                                                                           |
| **Enable TypeScript**<br>False                                                                                                        |
| **Add Eslint configuration**<br>True, see https://www.npmjs.com/package/@sap-ux/eslint-plugin-fiori-tools#rules for the eslint rules. |
| **Main Entity**<br>PoPrint                                                                                                            |

## zbak_po_print

采购订单打印

## 效果

![](C:/Users/bak/AppData/Roaming/marktext/images/2026-09-14-13-46-23-企业微信截图_17893642568951.png)



![](C:/Users/bak/AppData/Roaming/marktext/images/2026-09-14-13-46-35-企业微信截图_17893642816481.png)

##需要扩展ABAP RAP的action

 代码见webapp/ext

### Starting the generated app

- This app has been generated using the SAP Fiori tools - App Generator, as part of the SAP Fiori tools suite.  To launch the generated application, run the following from the generated application root folder:

```
    npm start
```

- It is also possible to run the application using mock data that reflects the OData Service URL supplied during application generation.  In order to run the application with Mock Data, run the following from the generated app root folder:

```
    npm run start-mock
```

#### Pre-requisites:

1. Active NodeJS LTS (Long Term Support) version and associated supported NPM version.  (See https://nodejs.org)

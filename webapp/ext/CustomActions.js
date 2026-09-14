sap.ui.define(
  [
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "sap/ui/core/BusyIndicator",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
  ],
  function (MessageBox, MessageToast, BusyIndicator, Filter, FilterOperator) {
    "use strict";

    function i18n(oController, sKey, sFallback) {
      try {
        var oBundle = oController
          .getView()
          .getModel("i18n")
          .getResourceBundle();
        return oBundle.getText(sKey) || sFallback;
      } catch (oError) {
        return sFallback;
      }
    }

    function binaryStringToBytes(sBin) {
      var aBytes = new Uint8Array(sBin.length);
      var i;
      for (i = 0; i < sBin.length; i++) {
        aBytes[i] = sBin.charCodeAt(i) & 0xff;
      }
      return aBytes;
    }

    function isPdfBytes(aBytes) {
      return (
        aBytes &&
        aBytes.length >= 4 &&
        aBytes[0] === 0x25 &&
        aBytes[1] === 0x50 &&
        aBytes[2] === 0x44 &&
        aBytes[3] === 0x46
      );
    }

    function isProbablyBase64(sValue) {
      var s = String(sValue).replace(/\s/g, "");
      if (s.indexOf("base64,") >= 0) {
        s = s.split("base64,").pop();
      }
      return s.length >= 16 && /^[A-Za-z0-9+/_-]+={0,2}$/.test(s);
    }

    function base64ToBytes(sValue) {
      var sBase64 = sValue.indexOf("base64,") >= 0
        ? sValue.split("base64,").pop()
        : sValue;
      sBase64 = sBase64.replace(/\s/g, "").replace(/-/g, "+").replace(/_/g, "/");
      while (sBase64.length % 4) {
        sBase64 += "=";
      }
      return binaryStringToBytes(window.atob(sBase64));
    }

    function isActionStreamUrl(sValue) {
      return typeof sValue === "string" && sValue.indexOf("previewPdf") >= 0;
    }

    function isPdfUrl(sValue) {
      return (
        typeof sValue === "string" &&
        !isActionStreamUrl(sValue) &&
        (sValue.indexOf("/sap/opu/") === 0 ||
          sValue.indexOf("http://") === 0 ||
          sValue.indexOf("https://") === 0)
      );
    }

    function toUint8Array(vPdf) {
      if (!vPdf) {
        return null;
      }
      if (vPdf instanceof Uint8Array) {
        return vPdf;
      }
      if (vPdf instanceof ArrayBuffer) {
        return new Uint8Array(vPdf);
      }
      if (ArrayBuffer.isView(vPdf)) {
        return new Uint8Array(vPdf.buffer, vPdf.byteOffset, vPdf.byteLength);
      }
      if (Array.isArray(vPdf)) {
        return new Uint8Array(vPdf);
      }
      if (typeof vPdf === "object" && vPdf.value != null) {
        return toUint8Array(vPdf.value);
      }
      if (typeof vPdf === "string") {
        if (vPdf.indexOf("%PDF") === 0) {
          return binaryStringToBytes(vPdf);
        }
        if (isPdfUrl(vPdf)) {
          return { url: vPdf };
        }
        if (isProbablyBase64(vPdf)) {
          try {
            return base64ToBytes(vPdf);
          } catch (oError) {
            return binaryStringToBytes(vPdf);
          }
        }
        return binaryStringToBytes(vPdf);
      }
      return null;
    }

    function asPdfBlob(oBlob) {
      if (oBlob && oBlob.type !== "application/pdf") {
        return new Blob([oBlob], { type: "application/pdf" });
      }
      return oBlob;
    }

    function triggerDownload(oBlob, bPrint) {
      var oPdf = asPdfBlob(oBlob);
      var sUrl = URL.createObjectURL(oPdf);
      var oWin = window.open(
        sUrl,
        "_blank",
        bPrint ? undefined : "noopener,noreferrer"
      );
      if (!oWin) {
        var oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.target = "_blank";
        oLink.rel = "noopener";
        oLink.style.display = "none";
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
      } else if (bPrint) {
        setTimeout(function () {
          try {
            oWin.focus();
            oWin.print();
          } catch (oError) {
            return;
          }
        }, 800);
      }
      setTimeout(function () {
        URL.revokeObjectURL(sUrl);
      }, 60000);
    }

    function fetchAsBlob(sUrl) {
      return fetch(sUrl, {
        credentials: "same-origin",
        headers: { Accept: "application/pdf,application/octet-stream,*/*" }
      }).then(function (oRes) {
        if (!oRes.ok) {
          throw new Error("HTTP " + oRes.status);
        }
        return oRes.blob();
      });
    }

    function serviceUrl(oModel) {
      var sService = oModel.getServiceUrl() || "";
      if (sService && sService.charAt(sService.length - 1) !== "/") {
        sService += "/";
      }
      return sService;
    }

    function loadPoPdf(oModel, sEbeln) {
      var oList = oModel.bindList("/PoPdf", undefined, undefined, [
        new Filter("ebelns", FilterOperator.EQ, sEbeln),
        new Filter("formid", FilterOperator.EQ, "ZMM_R002_03B")
      ]);

      return oList.requestContexts(0, 1).then(function (aCtx) {
        if (!aCtx || !aCtx.length) {
          return null;
        }
        var oRow = aCtx[0];
        return Promise.all([
          oRow.requestProperty("pdf"),
          oRow.requestProperty("filename"),
          oRow.requestProperty("mimetype"),
          oRow.requestProperty("message")
        ]).then(function (aVals) {
          return {
            pdf: aVals[0],
            filename: aVals[1],
            mimetype: aVals[2],
            message: aVals[3],
            context: oRow
          };
        });
      });
    }

    function downloadPdf(vPdf, sFileName, sMimeType, bPrint) {
      var vConverted;
      var sType = sMimeType || "application/pdf";

      if (vPdf instanceof Blob) {
        if (!vPdf.size) {
          return Promise.resolve(false);
        }
        triggerDownload(vPdf, bPrint);
        return Promise.resolve(true);
      }

      vConverted = toUint8Array(vPdf);
      if (vConverted && vConverted.url) {
        return fetchAsBlob(vConverted.url).then(function (oBlob) {
          if (!oBlob || !oBlob.size) {
            return false;
          }
          triggerDownload(oBlob, bPrint);
          return true;
        });
      }
      if (vConverted && isPdfBytes(vConverted)) {
        triggerDownload(new Blob([vConverted], { type: sType }), bPrint);
        return Promise.resolve(true);
      }
      if (vConverted && vConverted.length > 100) {
        triggerDownload(new Blob([vConverted], { type: sType }), bPrint);
        return Promise.resolve(true);
      }
      return Promise.resolve(false);
    }

    function previewFromPoPdf(oModel, sEbelns, bPrint) {
      return loadPoPdf(oModel, sEbelns).then(function (oRow) {
        var sStreamPath;
        if (!oRow) {
          return false;
        }
        if (oRow.message && !oRow.pdf) {
          throw new Error(oRow.message);
        }
        return downloadPdf(oRow.pdf, oRow.filename, oRow.mimetype, bPrint).then(
          function (bOk) {
            if (bOk) {
              return true;
            }
            sStreamPath = oRow.context.getCanonicalPath() + "/pdf";
            if (sStreamPath.indexOf("/") !== 0) {
              sStreamPath =
                serviceUrl(oModel) + sStreamPath.replace(/^\//, "");
            }
            return fetchAsBlob(sStreamPath).then(function (oBlob) {
              if (!oBlob || !oBlob.size) {
                return false;
              }
              triggerDownload(oBlob, bPrint);
              return true;
            });
          }
        );
      });
    }

    function writePrintLog(oController, aSelectedContexts) {
      var oEditFlow = oController.editFlow;
      if (oEditFlow && typeof oEditFlow.invokeAction === "function") {
        return oEditFlow.invokeAction(
          "com.sap.gateway.srvd.zui_mm_r002.v0001.confirmPrint",
          { contexts: aSelectedContexts }
        );
      }
      return Promise.all(
        aSelectedContexts.map(function (oCtx) {
          return invokeBoundAction(
            oCtx,
            "com.sap.gateway.srvd.zui_mm_r002.v0001.confirmPrint(...)"
          );
        })
      );
    }

    function errorText(oError) {
      var sMsg;
      if (!oError) {
        return "";
      }
      if (oError.error && oError.error.message) {
        return oError.error.message;
      }
      sMsg = oError.message;
      return sMsg || String(oError);
    }

    function invokeAction(oBinding) {
      if (typeof oBinding.invoke === "function") {
        return oBinding.invoke();
      }
      return oBinding.execute();
    }

    function invokeBoundAction(oContext, sAction) {
      var oAction = oContext.getModel().bindContext(sAction, oContext);
      return invokeAction(oAction);
    }

    return {
      singleSelection: function (oBindingContext, aSelectedContexts) {
        return !!(aSelectedContexts && aSelectedContexts.length === 1);
      },

      confirmPrint: function (oBindingContext, aSelectedContexts) {
        var oController = this;
        var aEbeln;
        var sEbelns;

        if (!aSelectedContexts || !aSelectedContexts.length) {
          MessageToast.show(
            i18n(oController, "selectFirst", "请先勾选采购订单")
          );
          return Promise.resolve();
        }

        aEbeln = aSelectedContexts.map(function (oCtx) {
          return oCtx.getProperty("ebeln");
        });
        sEbelns = aEbeln.join(";");
        BusyIndicator.show(0);

        return previewFromPoPdf(aSelectedContexts[0].getModel(), sEbelns, true)
          .then(function (bOk) {
            if (!bOk) {
              throw new Error(i18n(oController, "pdfEmpty", "未生成 PDF"));
            }
            return writePrintLog(oController, aSelectedContexts);
          })
          .then(function () {
            MessageToast.show(i18n(oController, "logSaved", "已写入打印日志"));
            if (oController.getExtensionAPI) {
              oController.getExtensionAPI().refresh();
            }
          })
          .catch(function (oError) {
            MessageBox.error(
              errorText(oError) ||
                i18n(oController, "logFailed", "打印失败")
            );
          })
          .finally(function () {
            BusyIndicator.hide();
          });
      },

      previewPdf: function (oBindingContext, aSelectedContexts) {
        var oController = this;
        var oContext;

        if (!aSelectedContexts || aSelectedContexts.length !== 1) {
          MessageToast.show(
            i18n(oController, "selectExactlyOne", "请勾选一条采购订单")
          );
          return Promise.resolve();
        }

        oContext = aSelectedContexts[0];
        BusyIndicator.show(0);

        return previewFromPoPdf(
          oContext.getModel(),
          oContext.getProperty("ebeln"),
          false
        )
          .then(function (bOk) {
            if (!bOk) {
              MessageBox.error(i18n(oController, "pdfEmpty", "未生成 PDF"));
            }
          })
          .catch(function (oError) {
            MessageBox.error(
              errorText(oError) ||
                i18n(oController, "pdfFailed", "获取 PDF 失败")
            );
          })
          .finally(function () {
            BusyIndicator.hide();
          });
      },
    };
  },
);

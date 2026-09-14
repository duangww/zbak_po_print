sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zbakpoprint/test/integration/pages/PoPrintList.gen",
	"zbakpoprint/test/integration/pages/PoPrintObjectPage.gen"
], function (JourneyRunner, PoPrintListGenerated, PoPrintObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zbakpoprint') + '/test/flp.html#app-preview',
        pages: {
			onThePoPrintListGenerated: PoPrintListGenerated,
			onThePoPrintObjectPageGenerated: PoPrintObjectPageGenerated
        },
        async: true
    });

    return runner;
});


{{flutter_js}}
{{flutter_build_config}}

// Loads the app. Replaces Flutter's generated bootstrap for three reasons:
//
// 1. The rendering engine (CanvasKit) comes from this server, not from
//    www.gstatic.com. The build already ships it under canvaskit/ and the
//    server caches it for a week; the default would make every first visit
//    open a second connection to Google and wait on it, and on a network that
//    filters or blocks gstatic the app would never start at all — a white page
//    with no error.
// 2. No Flutter service worker. Flutter has deprecated it, it only added a
//    startup wait (up to 4 s on slow phones), and the push worker in push/ is
//    the one this app relies on.
// 3. The loading screen in index.html is removed only once the first frame is
//    up, and a failure shows a "try again" button instead of a blank page.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      // One frame later, so the splash fades over the app rather than over
      // the empty canvas.
      requestAnimationFrame(function () {
        if (window.__upSplashDone) window.__upSplashDone();
      });
    } catch (e) {
      console.error('UP failed to start', e);
      if (window.__upSplashFail) window.__upSplashFail();
    }
  },
}).catch(function (e) {
  console.error('UP failed to load', e);
  if (window.__upSplashFail) window.__upSplashFail();
});

// WHERE YOU ARE, asked once, when a passport is issued.
//
// Ported whole from the project this app grew out of, and the part worth
// keeping is the permission handling rather than the request. Asking the
// browser for coordinates is four lines; what takes the rest is that a refusal
// is not final. Somebody says no, goes to the address bar, changes their mind —
// and without the permission listener below they would have to reload the page
// to be asked again, which nobody does. So the page re-asks the moment the
// permission flips, and the step they are stuck on unsticks itself.
//
// IT ALSO HEARS A REVOCATION, and reports it, so the gate re-engages. You
// cannot be placed on coordinates you have taken back.
interface GeoCtx {
  pushEvent: (event: string, payload: object) => void;
  handleEvent: (event: string, cb: (payload: object) => void) => void;
  request: () => void;
}

export const Geolocation = {
  mounted(this: GeoCtx) {
    this.request();
    this.handleEvent("request_location", () => this.request());

    if (navigator.permissions?.query) {
      navigator.permissions
        .query({ name: "geolocation" as PermissionName })
        .then((status) => {
          status.onchange = () => {
            if (status.state === "granted") this.request();
            else this.pushEvent("geo_lost", {});
          };
        })
        .catch(() => {});
    }
  },

  request(this: GeoCtx) {
    if (!("geolocation" in navigator)) {
      // No API at all reads the same as the hardware being unable to answer:
      // either way there is nothing coming, and the difference is not something
      // the person can act on.
      this.pushEvent("geo_error", { code: 2 });
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) =>
        this.pushEvent("geo", {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
        }),
      // 1 = denied, 2 = unavailable, 3 = timed out.
      (err) => this.pushEvent("geo_error", { code: err.code }),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
    );
  },
};

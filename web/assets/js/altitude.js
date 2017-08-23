export function altitudeToColor(altitude) {
  // Original source: https://github.com/flightaware/dump1090/blob/master/public_html/planeObject.js

  let h, s, l

  if (typeof altitude === 'undefined' || altitude === null) {
    return [0, 0, 0]
  }

  s = 85
  l = 50

  let hpoints = [{alt: 2000,  val: 20},   // orange
                 {alt: 10000, val: 140},  // light green
                 {alt: 40000, val: 300}]  // magenta

  h = hpoints[0].val

  for (let i = hpoints.length-1; i >= 0; --i) {
    if (altitude > hpoints[i].alt) {
      if (i == hpoints.length-1) {
        h = hpoints[i].val
      } else {
        h = hpoints[i].val + (hpoints[i+1].val - hpoints[i].val) * (altitude - hpoints[i].alt) / (hpoints[i+1].alt - hpoints[i].alt)
      }
      break
    }
  }

  if (h < 0) {
    h = (h % 360) + 360
  } else if (h >= 360) {
    h = h % 360
  }

  if (s < 5) {
    s = 5
  } else if (s > 95) {
    s = 95
  }

  if (l < 5) {
    l = 5
  } else if (l > 95) {
    l = 95
  }

  return hslToHex(h, s, l)
}

function hslToHex(h, s, l) {
  // Source: https://stackoverflow.com/questions/36721830/convert-hsl-to-rgb-and-hex
  h /= 360;
  s /= 100;
  l /= 100;
  let r, g, b;
  if (s === 0) {
    r = g = b = l; // achromatic
  } else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  const toHex = x => {
    const hex = Math.round(x * 255).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  };
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

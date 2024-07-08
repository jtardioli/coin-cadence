export function numberToBytes3(num: number) {
  if (num < 0 || num > 0xffffff) {
    throw new Error("Number out of range for bytes3");
  }
  let hexString = num.toString(16);
  while (hexString.length < 6) {
    hexString = "0" + hexString;
  }
  return `0x${hexString}`;
}

export function concatBytes(arr: string[]) {
  const removeOxstring = arr.join("").replace(/0x/g, "");
  console.log({ removeOxstring });
  return "0x" + removeOxstring;
}

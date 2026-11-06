import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// The app's Info.plist is the only place the version is written down.
const plist = readFileSync(resolve(process.cwd(), '../Resources/Info.plist'), 'utf8');
const match = plist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/);

if (!match) throw new Error('CFBundleShortVersionString is missing from Resources/Info.plist');

export const version = match[1];
export const repo = 'https://github.com/EQuimper/KeyHop';
export const brewInstall = 'brew install --cask equimper/tap/keyhop';

import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../finicky.js', import.meta.url), 'utf8');
const config = (await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)).default;
const scriptable = readFileSync(new URL('../../scriptable/DeepLink.js', import.meta.url), 'utf8');
const wrapper = (target) => `https://open.scriptable.app/run/DeepLink?url=${encodeURIComponent(target)}`;

function route(input) {
  let url = new URL(input);
  for (const rule of config.rewrite) {
    if (rule.match(url)) url = new URL(rule.url(url));
  }
  const handler = config.handlers.find(rule => rule.match(url));
  const selector = handler ? handler.browser : config.defaultBrowser;
  return {url: url.href, browser: typeof selector === 'function' ? selector(url) : selector};
}

function scriptableTarget(value) {
  let opened;
  vm.runInNewContext(scriptable, {
    args: {queryParameters: {url: value}},
    Safari: {open: target => { opened = target; }},
    Script: {complete() {}},
  });
  return new URL(opened).href;
}

test('matches Scriptable decoding without corrupting destination queries', () => {
  for (const target of [
    'message://<sample+test@example.invalid>',
    'MESSAGE://%3Csample%2Btest%40example.invalid%3E',
    'message://%253Csample%2540example.invalid%253E',
    'https://example.invalid/path?q=a%26b&next=x%3Dy#section',
    'obsidian://open?vault=Notes&file=Some%20Note',
    'shortcuts://run-shortcut?name=Example&input=text&text=a%26b',
    'zotero://select/library/items/EXAMPLE1',
    'mailto:person@example.invalid?subject=Example',
  ]) {
    for (let layers = 0; layers < 3; layers += 1) {
      let value = target;
      for (let i = 0; i < layers; i += 1) value = encodeURIComponent(value);
      assert.equal(route(wrapper(value)).url, scriptableTarget(value));
    }
  }
});

test('Mail gets normalized links and retains the old type=mail format', () => {
  for (const input of [wrapper('message://<sample@example.invalid>'),
    'https://open.scriptable.app/run/DeepLink?type=mail&id=%3Csample%40example.invalid%3E']) {
    assert.deepEqual(route(input), {url:'message://%3Csample%40example.invalid%3E',browser:'Mail'});
  }
});

test('web destinations use Safari; app destinations are passed as one argv value', () => {
  assert.equal(route(wrapper('https://example.invalid/')).browser,'Safari');
  const target='obsidian://open?vault=Notes&file=%22%3B%24%28touch%20test%29';
  const result=route(wrapper(target));
  assert.equal(result.browser.appType,'path');
  assert.deepEqual(result.browser.args,['-n','--args',new URL(target).href]);
});

test('invalid input and unrelated Scriptable scripts are left alone', () => {
  for (const input of [
    wrapper(''),wrapper('relative/path'),wrapper('%zz'),wrapper('finicky://example'),
    'https://open.scriptable.app/run/DeepLink?type=mail&id=%20',
    'https://other.example/run/DeepLink?url=obsidian%3A%2F%2Fopen',
    'https://open.scriptable.app/run/Other?url=obsidian%3A%2F%2Fopen',
  ]) {
    assert.deepEqual(route(input),{url:new URL(input).href,browser:'Safari'});
  }
});

test('native helper forwards one literal argument and refuses browser loops', () => {
  const directory = mkdtempSync(join(tmpdir(), 'deeplink-test-'));
  try {
    const stub = join(directory, 'open');
    writeFileSync(stub, '#!/bin/sh\nprintf "%s\\n" "$#" "$1"\n', {mode:0o755});
    const helper = join(directory, 'helper.sh');
    // Replace only the executable in a temporary test copy. Never open URLs.
    writeFileSync(helper, readFileSync(new URL('../open-url.sh', import.meta.url), 'utf8')
      .replace('exec /usr/bin/open', 'exec "$TEST_OPEN"'));
    const target='obsidian://open?file=";$(printf injected)&vault=Some Vault';
    const result = spawnSync('/bin/sh', [helper, target], {encoding:'utf8',env:{...process.env,TEST_OPEN:stub}});
    assert.equal(result.status,0);
    assert.equal(result.stdout,`1\n${target}\n`);
    for (const target of ['https://example.invalid','HTTP://example.invalid','finicky://example','relative']) {
      const rejected = spawnSync('/bin/sh',[helper,target],{encoding:'utf8',env:{...process.env,TEST_OPEN:stub}});
      assert.equal(rejected.status,64);
      assert.equal(rejected.stdout,'');
    }
  } finally {
    rmSync(directory,{recursive:true,force:true});
  }
});

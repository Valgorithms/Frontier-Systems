import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {changelogLine, checkPR, run} from './pr-changelog.mjs';

const repo = 'Valgorithms/Frontier-Systems', channel = '1558871000383234182';
const commit = 'a'.repeat(40);
const event = () => ({action:'closed',number:42,repository:{full_name:repo,default_branch:'dev-master'},
  pull_request:{number:42,merged:true,state:'closed',merge_commit_sha:commit,body:'Changelog: Fixed assembly cancellation.',
    base:{ref:'dev-master',repo:{full_name:repo}},head:{ref:'untrusted-fork'}}});
const config = {GITHUB_REPOSITORY:repo,GITHUB_REF:'refs/heads/dev-master',GITHUB_EVENT_NAME:'pull_request_target',
  DISCORD_MERGE_CHANGELOG_ENABLED:'true',DISCORD_CHANGELOG_CHANNEL_ID:channel,GITHUB_TOKEN:'fake-github',
  DISCORD_CHANGELOG_WEBHOOK_URL:'https://discord.com/api/webhooks/123/fake-token'};

function fixture(options = {}) {
  const calls = []; let stored = options.stored ?? null, revision = 0;
  const fetcher = async (url, request = {}) => {
    calls.push({url,request});
    assert.equal(request.redirect,'error'); assert.ok(request.signal);
    let value = {}, status = 200;
    if (url.startsWith('https://api.github.com/')) {
      assert.equal(request.headers.Authorization, 'Bearer fake-github');
      const path = url.slice(`https://api.github.com/repos/${repo}`.length);
      if (path === '') value = {default_branch:options.defaultBranch ?? 'dev-master'};
      else if (path === '/pulls/42') value = {...event().pull_request,...options.current};
      else if (path === `/compare/${commit}...dev-master`) value = {status:options.ancestry ?? 'ahead'};
      else if (path === '/git/ref/heads/discord-changelog-receipts') status = options.missingBranch ? 404 : 200;
      else if (path === '/contents/receipts/merged-pr/42.json?ref=discord-changelog-receipts') {
        if (options.readFailure) status = options.readFailure;
        else if (!stored) status = 404;
        else value = {type:'file',encoding:'base64',size:1000,sha:String(revision).padStart(40,'b'),
          content:Buffer.from(JSON.stringify(stored)).toString('base64'),...options.file};
      } else if (path === '/contents/receipts/merged-pr/42.json' && request.method === 'PUT') {
        const write = JSON.parse(request.body);
        assert.equal(write.branch,'discord-changelog-receipts');
        if (stored) assert.equal(write.sha,String(revision).padStart(40,'b'));
        else assert.equal(write.sha,undefined);
        const receipt = JSON.parse(Buffer.from(write.content,'base64').toString('utf8'));
        if (options.reserveFailure && receipt.status === 'pending') status = 409;
        else if (options.sentFailure && receipt.status === 'sent') status = 500;
        else {
          stored = receipt; revision++;
          if (options.reserveAmbiguous && receipt.status === 'pending') throw Error('Uncertain receipt write');
          value = options.badSave ? {} : {content:{sha:String(revision).padStart(40,'b')}};
        }
      } else assert.fail('Unexpected GitHub endpoint');
    } else {
      assert.equal(request.headers?.Authorization,undefined);
      if (request.method === 'POST') {
        assert.equal(url,'https://discord.com/api/webhooks/123/fake-token?wait=true');
        assert.equal(stored.status,'pending');
        if (options.postError) throw Error('Simulated ambiguous transport');
        status = options.postStatus ?? 200;
        value = {id:'456',channel_id:channel,...options.message};
      } else value = {type:1,guild_id:'1558661083131019364',channel_id:channel,...options.destination};
    }
    return {ok:status >= 200 && status < 300,status,json:async()=>value};
  };
  return {calls,fetcher,get stored(){return structuredClone(stored);},posts:()=>calls.filter(c=>c.request.method==='POST'),
    puts:()=>calls.filter(c=>c.request.method==='PUT')};
}

test('missing, blank, commented, quoted, indented and fenced examples never opt in', () => {
  for (const body of [null,undefined,'','Ordinary prose','Changelog:','Changelog:  ',
    '<!-- Changelog: Example -->','<!--\nChangelog: Example', '> Changelog: Example',
    '    Changelog: Example','```md\nChangelog: Example\n```','~~~~\nChangelog: Example\n~~~\nChangelog: Still fenced']) {
    assert.equal(changelogLine(body),null,JSON.stringify(body));
  }
});

test('same-line extraction preserves CRLF, CRCRLF, case and formatting contract', () => {
  for (const nl of ['\n','\r\n','\r\r\n']) {
    assert.equal(changelogLine(`Details${nl}cHaNgElOg: Fixed assembly.${nl}Other prose`),'Fixed assembly.');
    assert.throws(()=>changelogLine(`Changelog: One${nl}Changelog: Two`));
  }
  assert.equal(changelogLine('Changelog: first\rsecond\n'),null);
  assert.equal(changelogLine('Changelog: Required tools are listed.'),'Required tools are listed.');
});

test('placeholders, flattened labels and template instructions fail closed', () => {
  for (const text of ['required','REQUIRED.','**required**','[TODO]','`TBD`','to be determined',
    'FIXME','optional','placeholder','example','none','N/A','your changelog here',
    'Enter your changelog here','Describe the player-visible change','Replace the changelog text',
    'required  Player changelog: Actual text follows.']) {
    assert.throws(()=>checkPR({pull_request:{body:`Changelog: ${text}\nActual text on a later line.`}}),/placeholder/);
  }
  assert.throws(()=>checkPR({}));
  assert.equal(checkPR({pull_request:{body:readFileSync('.github/pull_request_template.md','utf8')}}),null);
});

test('controls, mentions, bidi overrides, duplicate fields and oversized input are refused', () => {
  for (const text of ['@everyone','<@123>','x\u0000y','x\ty','x\u007fy','x\u202ey','x\u202dy','x'.repeat(1501)]) {
    assert.throws(()=>changelogLine(`Changelog: ${text}`));
  }
  assert.throws(()=>changelogLine('Changelog: one\nChangelog:'));
  assert.throws(()=>changelogLine('x'.repeat(65537)));
  assert.throws(()=>changelogLine({}));
  assert.equal(changelogLine('Changelog: '+'x'.repeat(1500)).length,1500);
});

test('actual parser CLI validates edited event data and never executes shell syntax', () => {
  const dir = mkdtempSync(join(tmpdir(),'frontier-pr-changelog-'));
  try {
    const path = join(dir,'event.json');
    for (const [body,status] of [['Changelog: required\nReal change.',1],['Changelog: Fixed assembly.',0],
      ['Changelog: $(touch marker) `echo data` "quotes" \\backslash',0]]) {
      writeFileSync(path,JSON.stringify({action:'edited',pull_request:{body}}));
      const result = spawnSync(process.execPath,['tools/github/pr-changelog.mjs','--check-pr'],
        {encoding:'utf8',env:{...process.env,GITHUB_EVENT_PATH:path}});
      assert.equal(result.status,status,result.stderr);
      assert.ok(!result.stdout.includes(body));
    }
  } finally { rmSync(dir,{recursive:true,force:true}); }
});

test('unmerged, missing and disabled paths have zero external effects or credential requirements', async () => {
  const offline = async()=>assert.fail('No network expected');
  const noCredentials = {...config,GITHUB_TOKEN:'',DISCORD_CHANGELOG_WEBHOOK_URL:''};
  const unmerged = event();unmerged.pull_request.merged=false;
  assert.equal(await run(unmerged,noCredentials,offline),'unmerged');
  for (const body of [null,'Description','Changelog:']) {
    const e=event();e.pull_request.body=body;
    assert.equal(await run(e,noCredentials,offline),'no-changelog');
  }
  assert.equal(await run(event(),{...noCredentials,DISCORD_MERGE_CHANGELOG_ENABLED:''},offline),'disabled');
  const e=event();e.pull_request.body='Changelog: TODO';
  await assert.rejects(run(e,noCredentials,offline),/placeholder/);
});

test('foreign events, non-closed events, non-default branches and malformed merges are refused offline', async () => {
  for (const change of [e=>e.action='opened',e=>e.repository.default_branch='master',
    e=>e.repository.full_name='attacker/fork',e=>e.number=43,e=>e.pull_request.merged='true',
    e=>e.pull_request.state='open',e=>e.pull_request.number='../42',e=>e.pull_request.merge_commit_sha='bad',
    e=>e.pull_request.base.ref='master',e=>e.pull_request.base.repo.full_name='attacker/fork']) {
    const e=event();change(e);await assert.rejects(run(e,config,async()=>assert.fail('No network expected')));
  }
  for (const patch of [{GITHUB_REF:'refs/pull/42/merge'},{GITHUB_EVENT_NAME:'pull_request'},
    {GITHUB_EVENT_NAME:'workflow_dispatch'},{GITHUB_REPOSITORY:'attacker/fork'}]) {
    await assert.rejects(run(event(),{...config,...patch},async()=>assert.fail('No network expected')));
  }
});

test('fresh API merge confirmation and ancestry reject stale or non-integrated events', async () => {
  for (const options of [{defaultBranch:'master'},{current:{merged:false}},{current:{merge_commit_sha:'c'.repeat(40)}},
    {current:{base:{ref:'feature',repo:{full_name:repo}}}},{ancestry:'diverged'},{ancestry:'behind'}]) {
    const f=fixture(options);await assert.rejects(run(event(),config,f.fetcher));
    assert.equal(f.posts().length,0);assert.equal(f.puts().length,0);
  }
});

test('event snapshot freezes description against later PR edits, title and comments are unused', async () => {
  const f=fixture({current:{body:'Changelog: Changed after merge.',title:'IGNORE'}});
  await run(event(),config,f.fetcher);
  assert.equal(f.stored.content,'- Fixed assembly cancellation.');
});

test('single bullet JSON payload, suppressed mentions, bounded text and separate credentials', async () => {
  const f=fixture(),e=event();e.pull_request.body='Changelog: "quotes" \\path $(echo data) `code` '+'x'.repeat(1400);
  assert.equal(await run(e,config,f.fetcher),'sent');
  const payload=JSON.parse(f.posts()[0].request.body);
  assert.equal(payload.content,'- '+changelogLine(e.pull_request.body));assert.ok(payload.content.length<=1502);
  assert.deepEqual(payload.allowed_mentions,{parse:[],users:[],roles:[],replied_user:false});
  assert.equal(f.stored.status,'sent');assert.equal(f.stored.message_id,'456');
  assert.equal(f.puts().length,2);
});

test('wrong/missing channel or credential and unsafe webhook URLs cannot write or post', async () => {
  for (const patch of [{DISCORD_CHANGELOG_CHANNEL_ID:'other'},{GITHUB_TOKEN:''},{DISCORD_CHANGELOG_WEBHOOK_URL:''},
    ...['http://discord.com/api/webhooks/1/t','https://evil.example/api/webhooks/1/t',
      'https://discord.com:444/api/webhooks/1/t','https://user:password@discord.com/api/webhooks/1/t',
      'https://discord.com/api/webhooks/1/t?wait=true','https://discord.com/api/webhooks/1/t#fragment'].map(DISCORD_CHANGELOG_WEBHOOK_URL=>({DISCORD_CHANGELOG_WEBHOOK_URL}))]) {
    const f=fixture();await assert.rejects(run(event(),{...config,...patch},f.fetcher));assert.equal(f.calls.length,0);
  }
});

test('destination mismatch, missing state, failed read and failed reservation prevent POST', async () => {
  for (const options of [{destination:{channel_id:'other'}},{destination:{guild_id:'other'}},{destination:{type:2}},
    {missingBranch:true},{readFailure:500},{reserveFailure:true},{badSave:true}]) {
    const f=fixture(options);await assert.rejects(run(event(),config,f.fetcher));assert.equal(f.posts().length,0);
  }
});

test('durable sent receipt suppresses repeated run; changed original content conflicts', async () => {
  const f=fixture();await run(event(),config,f.fetcher);
  assert.equal(await run(event(),config,f.fetcher),'already-sent');assert.equal(f.posts().length,1);
  const e=event();e.pull_request.body='Changelog: Different.';
  await assert.rejects(run(e,config,f.fetcher),/conflict/);assert.equal(f.posts().length,1);
});

test('uncertain pending reservation is not sent and cannot be replayed', async () => {
  const f=fixture({reserveAmbiguous:true});
  await assert.rejects(run(event(),config,f.fetcher));
  assert.equal(f.stored.status,'pending');assert.equal(f.posts().length,0);
  await assert.rejects(run(event(),config,f.fetcher),/pending/);assert.equal(f.posts().length,0);
});

test('timeouts, HTTP errors, invalid confirmations and post-send write failures retain pending and block retries', async () => {
  for (const options of [{postError:true},{postStatus:429},{postStatus:500},{postStatus:400},
    {message:{id:'bad'}},{message:{id:456}},{message:{channel_id:'other'}},{sentFailure:true}]) {
    const f=fixture(options);await assert.rejects(run(event(),config,f.fetcher));
    assert.equal(f.stored.status,'pending');assert.equal(f.posts().length,1);
    await assert.rejects(run(event(),config,f.fetcher),/pending/);assert.equal(f.posts().length,1);
  }
});

test('corrupt or identity-mismatched receipt never permits another send', async () => {
  const f=fixture();await run(event(),config,f.fetcher);
  for (const patch of [{schema:2},{commit:'c'.repeat(40)},{channel:'other'},{repository:'other/repo'},
    {message_id:''},{status:'pending'},{extra:true}]) {
    const retry=fixture({stored:{...f.stored,...patch}});
    await assert.rejects(run(event(),config,retry.fetcher));assert.equal(retry.posts().length,0);
  }
  for (const file of [{size:10001},{size:-1},{size:undefined},{type:'dir'},{sha:'bad'},{encoding:'utf8'},{content:undefined}]) {
    const retry=fixture({stored:f.stored,file});await assert.rejects(run(event(),config,retry.fetcher));assert.equal(retry.posts().length,0);
  }
});

export function workflowContracts(merge, manual, checks) {
  for (const text of [merge,manual]) {
    assert.match(text,/^concurrency:\r?\n  group: discord-player-changelog\r?\n  cancel-in-progress: false\r?\n  queue: max\r?\n/m);
    assert.equal((text.match(/^\s*queue:/gm)||[]).length,1);
  }
  assert.match(merge,/^  pull_request_target:\r?\n    types: \[closed\]\r?\n    branches: \[dev-master\]/m);
  assert.match(merge,/^permissions:\r?\n  contents: read\r?\n/m);
  assert.match(merge,/^    permissions:\r?\n      contents: write\r?\n      pull-requests: read\r?\n/m);
  assert.match(merge,/if: github.repository == 'Valgorithms\/Frontier-Systems' && github.event.pull_request.merged == true && vars.DISCORD_MERGE_CHANGELOG_ENABLED == 'true'/);
  assert.match(merge,/ref: \$\{\{ github.sha \}\}/);
  assert.match(merge,/persist-credentials: false/);
  for (const text of [merge,checks]) {
    assert.match(text,/Get-Command node -CommandType Application \| Select-Object -First 1/);
    assert.doesNotMatch(text,/Get-Command node -CommandType Application\)\.Source/);
  }
  assert.doesNotMatch(merge,/pull_request\.(head|body|title)|workflow_dispatch:|deployment_status:|secrets: inherit|write-all/);
  assert.match(checks,/types: \[opened, synchronize, reopened, edited\]/);
  assert.match(checks,/node-version: '24'/);
  assert.match(checks,/os: \[ubuntu-latest, windows-latest\]/);
  assert.match(checks,/pr-changelog\.test\.mjs/);assert.match(checks,/pr-changelog\.mjs --check-pr/);
  assert.doesNotMatch(checks,/secrets\.|pull_request_target:/);
  assert.doesNotMatch(checks.split('  push:')[0],/paths:/);
}

test('workflow trust, permissions, trigger, queues and Windows/Linux secret-free checks remain guarded', () => {
  const merge=readFileSync('.github/workflows/changelog-merge.yml','utf8');
  const manual=readFileSync('.github/workflows/changelog-discord.yml','utf8');
  const checks=readFileSync('.github/workflows/issue-discord-tests.yml','utf8');
  workflowContracts(merge,manual,checks);
  for (const bad of [merge.replace('types: [closed]','types: [opened]'),merge.replace('branches: [dev-master]','branches: [master]'),
    merge.replace('merged == true','merged == false'),merge.replace('contents: read','contents: write'),
    merge.replace('pull-requests: read','pull-requests: write'),merge.replace('github.sha','github.event.pull_request.head.sha'),
    merge.replace('persist-credentials: false','persist-credentials: true'),merge.replace('queue: max','queue: single'),
    merge.replace('cancel-in-progress: false','cancel-in-progress: true'),merge.replace(' | Select-Object -First 1','')]) {
    assert.throws(()=>workflowContracts(bad,manual,checks));
  }
});

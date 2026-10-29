import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {webhookURL} from './issue-discord.mjs';

const repository = 'Valgorithms/Frontier-Systems';
const branch = 'dev-master';
const receiptBranch = 'discord-changelog-receipts';
const channel = '1558871000383234182';
const guild = '1558661083131019364';
const shaPattern = /^[a-f0-9]{40}$/;

function withoutComments(text) {
  let visible = '', cursor = 0;
  while (cursor < text.length) {
    const start = text.indexOf('<!--',cursor);
    if (start < 0) return visible + text.slice(cursor);
    visible += text.slice(cursor,start);
    const end = text.indexOf('-->',start+4);
    if (end < 0) break;
    cursor = end+3;
  }
  return visible;
}

function trimMarker(text, punctuation = false) {
  const decoration = character => /\s/u.test(character) || '`*_[]{}:'.includes(character)
    || (punctuation && '.!?'.includes(character));
  let start = 0, end = text.length;
  // Opening punctuation is meaningful, matching the contribution contract.
  while (start < end && (/\s/u.test(text[start]) || '`*_[]{}:'.includes(text[start]))) start++;
  while (end > start && decoration(text[end-1])) end--;
  return text.slice(start,end).trim();
}

function templateInstruction(text) {
  let rest = text;
  const verb = ['enter','insert','write','add','fill in','describe','replace'].find(word=>rest.startsWith(word+' '));
  if (!verb) return false;
  rest = rest.slice(verb.length+1);
  for (const determiner of ['the ','your ','a ']) if (rest.startsWith(determiner)) { rest = rest.slice(determiner.length); break; }
  return ['changelog','player-facing','player-visible'].some(word=>rest.startsWith(word) && !/\w/.test(rest[word.length] || ''));
}

// Independently implemented from the documented Civ13 contribution contract.
// PR prose remains data: it is never evaluated, imported, or passed to a shell.
export function changelogLine(body) {
  if (body === null || body === undefined) return null;
  if (typeof body !== 'string' || body.length > 65536) throw Error('Invalid PR description');
  const lines = withoutComments(body).replace(/\r+(?=\n)/g,'').split('\n');
  let fenceCharacter = '', fenceLength = 0;
  const entries = [];
  for (const line of lines) {
    const prefix = line.trimStart();
    const fence = prefix[0];
    let length = 0;
    if (fence === '`' || fence === '~') while (prefix[length] === fence) length++;
    if (length >= 3) {
      if (!fenceCharacter) { fenceCharacter = fence; fenceLength = length; }
      else if (fence === fenceCharacter && length >= fenceLength) fenceCharacter = '';
      continue;
    }
    if (fenceCharacter) continue;
    if (line.slice(0,10).toLowerCase() === 'changelog:' && !/[\r\u2028\u2029]/u.test(line)) entries.push(line.slice(10).trim());
  }
  if (entries.length > 1) throw Error('Use only one Changelog: line');
  const entry = entries[0];
  if (!entry) return null;
  const marker = trimMarker(entry.normalize('NFKC').toLowerCase(),true);
  const firstMarker = trimMarker(marker.split(/\s+player changelog\s*:/)[0],true);
  const placeholders = ['required','optional','todo','to do','tbd','to be determined','fixme',
    'pending','placeholder','example','none','n/a','not applicable','no changelog',
    'your changelog here','changelog text here','player-facing text here'];
  if (placeholders.includes(firstMarker) || templateInstruction(marker)) {
    throw Error('Changelog placeholder: fill in the same line or leave it blank');
  }
  if (entry.length > 1500 || /[\u0000-\u001f\u007f@<>\u202d\u202e]/u.test(entry)) throw Error('Unsafe or oversized changelog');
  return entry;
}

export function checkPR(event) {
  if (!event?.pull_request || !Object.hasOwn(event.pull_request, 'body')) throw Error('Expected PR description');
  return changelogLine(event.pull_request.body);
}

function mergedPR(pr, number) {
  return Number.isSafeInteger(number) && number > 0 && pr?.number === number
    && pr.merged === true && pr.state === 'closed' && shaPattern.test(pr.merge_commit_sha || '')
    && pr.base?.ref === branch && pr.base?.repo?.full_name === repository;
}

export async function run(event, env, fetcher = fetch) {
  if (env.GITHUB_REPOSITORY !== repository || env.GITHUB_REF !== `refs/heads/${branch}`
    || env.GITHUB_EVENT_NAME !== 'pull_request_target' || event.repository?.full_name !== repository
    || event.repository?.default_branch !== branch || event.action !== 'closed') throw Error('Untrusted merge context');
  if (event.pull_request?.merged === false) return 'unmerged';
  const pr = event.pull_request;
  if (!mergedPR(pr, event.number)) throw Error('Expected merged default-branch PR');
  const entry = checkPR(event);
  if (!entry) return 'no-changelog';
  // Disabled means no network, credential use, or durable state mutation.
  if (env.DISCORD_MERGE_CHANGELOG_ENABLED !== 'true') return 'disabled';
  if (!env.GITHUB_TOKEN || env.DISCORD_CHANGELOG_CHANNEL_ID !== channel) throw Error('Missing or incorrect configuration');
  const hook = webhookURL(env.DISCORD_CHANGELOG_WEBHOOK_URL);
  if (hook.port) throw Error('Invalid webhook port');
  const headers = {Authorization:`Bearer ${env.GITHUB_TOKEN}`,Accept:'application/vnd.github+json',
    'Content-Type':'application/json','X-GitHub-Api-Version':'2022-11-28'};
  const request = async (url, options = {}, absent = false) => {
    // No automatic HTTP retries, especially after ambiguous POST/PUT outcomes.
    const response = await fetcher(url, {...options, redirect:'error', signal:AbortSignal.timeout(15000)});
    if (absent && response.status === 404) return null;
    if (!response.ok) throw Error('Remote request failed');
    return response.json();
  };
  const api = (path, options, absent) => request(`https://api.github.com/repos/${repository}${path}`, {headers,...options}, absent);
  const currentRepo = await api('');
  const current = await api(`/pulls/${pr.number}`);
  if (currentRepo.default_branch !== branch || !mergedPR(current, pr.number)
    || current.merge_commit_sha !== pr.merge_commit_sha) throw Error('Merge confirmation mismatch');
  const ancestry = await api(`/compare/${pr.merge_commit_sha}...${branch}`);
  if (!['ahead','identical'].includes(ancestry.status)) throw Error('Merge commit is not integrated');
  await api(`/git/ref/heads/${receiptBranch}`); // Never provision state implicitly.
  const path = `/contents/receipts/merged-pr/${pr.number}.json`;
  const file = await api(`${path}?ref=${receiptBranch}`, undefined, true);
  const identity = {schema:1, repository, pr:pr.number, commit:pr.merge_commit_sha, channel, content:`- ${entry}`};
  let fileSha;
  if (file) {
    if (file.type !== 'file' || file.encoding !== 'base64' || !Number.isInteger(file.size) || file.size < 0
      || file.size > 10000 || typeof file.content !== 'string' || !shaPattern.test(file.sha || '')) throw Error('Invalid receipt file');
    const saved = JSON.parse(Buffer.from(file.content,'base64').toString('utf8'));
    const keys = [...Object.keys(identity),'status','message_id'].sort();
    if (!saved || Object.keys(saved).sort().join() !== keys.join()
      || Object.entries(identity).some(([key,value]) => saved[key] !== value)) throw Error('Receipt content conflict');
    if (saved.status !== 'sent' || typeof saved.message_id !== 'string' || !/^[0-9]+$/.test(saved.message_id)) throw Error('Reconcile pending or invalid receipt');
    return 'already-sent';
  }
  const info = await request(hook.href);
  if (info.type !== 1 || info.guild_id !== guild || info.channel_id !== channel) throw Error('Webhook destination mismatch');
  const save = async (status, message_id) => {
    const result = await api(path, {method:'PUT', body:JSON.stringify({branch:receiptBranch,
      message:`Record merged PR changelog ${pr.number}`,
      content:Buffer.from(JSON.stringify({...identity,status,message_id},null,2)+'\n').toString('base64'),
      ...(fileSha ? {sha:fileSha} : {})})});
    if (!shaPattern.test(result.content?.sha || '')) throw Error('Receipt confirmation missing');
    fileSha = result.content.sha;
  };
  await save('pending', ''); // Durable reservation precedes every external send.
  const destination = new URL(hook); destination.searchParams.set('wait','true');
  const message = await request(destination.href, {method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({content:identity.content,allowed_mentions:{parse:[],users:[],roles:[],replied_user:false}})});
  if (typeof message.id !== 'string' || !/^[0-9]+$/.test(message.id) || message.channel_id !== channel) throw Error('Discord confirmation invalid');
  await save('sent', message.id);
  return 'sent';
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const event = JSON.parse(await readFile(process.env.GITHUB_EVENT_PATH,'utf8'));
    if (process.argv.includes('--check-pr')) { checkPR(event); console.log('PR changelog description valid'); }
    else console.log(`PR changelog: ${await run(event,process.env)}`);
  } catch {
    // Never log PR text, webhook URLs, response bodies or credential-bearing errors.
    console.error('PR changelog failed; check configuration and reconcile pending receipts before retrying.');
    process.exitCode = 1;
  }
}

#!/usr/bin/env python3
"""Economy and progression model for What Lies Ahead.

Reads the game's data files (levels, waves, enemies, weapons, cosmetics,
data/progression/*) and plays a "typical player" through them on paper:

    python3 tools/economy_model.py                 the current data
    python3 tools/economy_model.py --rev=<commit>  the data as of a commit (before/after)
    python3 tools/economy_model.py --runs=24       rows of the per-run table (default 15)
    python3 tools/economy_model.py --markdown      tables as Markdown (for docs/ECONOMY.md)

The typical player plays sessions of two clears and one defeat (dying on wave
5), works through the worlds in order and then cycles them, carries two
weapons (the main takes 65% of the kills) and rotates the main through the
unlocked weapons. Skill is set by the constants below; they were matched to a
bot clear of Prize Pier (score 51.9k with 63% headshots and every wave
flawless) and then lowered to a human's.

The model mirrors the game's formulas (score_keeper.gd, run_tracker.gd,
spark_ledger.gd, contract_board.gd); the numbers all come from the data.
"""
import glob
import math
import os
import re
import subprocess
import sys

# ---- the typical player ---------------------------------------------------------
HEADSHOT_RATE = 0.35       # share of kills finished with a headshot
COMBO_MULT = 1.35          # average combo multiplier on kill score
COMBO_TENS = {True: 5, False: 2}      # times a combo passes a multiple of 10 (clear, defeat)
BEST_COMBO = {True: 14, False: 9}
MULTI_RATE = 0.07          # multi-kill chains per kill
LONGSHOT_RATE = 0.04
CLOSE_CALLS = {True: 2, False: 5}
FLAWLESS_WAVES = 2         # the first two waves of a run
TICKETS_KEPT = 0.5         # share of the run's tickets still unspent at the portal
MAIN_SHARE = 0.65          # kills taken by the main weapon
DEFEAT_WAVE = 5            # a defeat dies half-way through this wave
SESSION = (True, True, False)   # clear, clear, defeat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REV = None


# ---- reading the data -----------------------------------------------------------
def read(path):
    if REV:
        out = subprocess.run(['git', '-C', ROOT, 'show', '%s:%s' % (REV, path)], capture_output=True, text=True)
        return out.stdout if out.returncode == 0 else None
    full = os.path.join(ROOT, path)
    return open(full).read() if os.path.exists(full) else None


def listing(folder):
    if REV:
        out = subprocess.run(['git', '-C', ROOT, 'ls-tree', '-r', '--name-only', REV, folder], capture_output=True, text=True)
        return sorted(f for f in out.stdout.split() if f.endswith('.tres'))
    return sorted(os.path.relpath(f, ROOT) for f in glob.glob(os.path.join(ROOT, folder, '**', '*.tres'), recursive=True))


def value(text):
    text = text.strip()
    if text.startswith('&"') or text.startswith('"'):
        return text.strip('&"')
    if text in ('true', 'false'):
        return text == 'true'
    m = re.match(r'Packed\w+Array\((.*)\)$', text)
    if m:
        try:
            return [float(x) if '.' in x else int(x) for x in m.group(1).split(',') if x.strip()]
        except ValueError:
            return text
    try:
        return float(text) if '.' in text else int(text)
    except ValueError:
        return text


def fields(block):
    return {k: value(v) for k, v in re.findall(r'^(\w+) = (.*)$', block, re.M)}


def resource(path):
    """(fields of [resource], {sub id: fields}, raw text) of a .tres file."""
    text = read(path)
    if text is None:
        return {}, {}, ''
    head, _, res = text.partition('[resource]\n')
    subs = {sid: body for sid, body in re.findall(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', head, re.S)}
    return fields(res), subs, text


def load():
    d = {}
    d['rules'] = resource('data/progression/rules.tres')[0]
    d['eco'] = resource('data/progression/economy.tres')[0]
    d['curve'] = resource('data/progression/mastery_curve.tres')[0]
    d['enemies'] = {}
    for f in listing('data/enemies'):
        e = resource(f)[0]
        d['enemies'][e['id']] = e
    worlds = []
    for f in listing('data/worlds'):
        w, _, text = resource(f)
        for lf in re.findall(r'path="res://(data/levels/[^"]+)"', text):
            lv, _, ltext = resource(lf)
            wf = re.search(r'path="res://(data/levels/[^"]+_waves\.tres)"', ltext).group(1)
            ws, subs, _ = resource(wf)
            waves = []
            for sid in sorted(subs, key=lambda s: int(re.sub(r'\D', '', s) or 0)):
                spawn = re.search(r'spawns = \{(.*?)\}', subs[sid], re.S)
                waves.append({k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', spawn.group(1))})
            worlds.append((w.get('sort_order', 0), {'id': lv['id'], 'name': lv['display_name'], 'waves': waves, 'set': ws}))
    d['levels'] = [lv for _, lv in sorted(worlds, key=lambda x: x[0])]
    d['weapons'] = []
    for f in listing('data/weapons'):
        w, subs, _ = resource(f)
        unlock = fields(subs['unlock']).get('amount', 0) if 'unlock' in subs else 0
        d['weapons'].append({'id': w['id'], 'name': w['display_name'], 'level': unlock, 'order': w.get('sort_order', 0)})
    d['weapons'].sort(key=lambda w: w['order'])
    d['cosmetics'] = []
    for f in listing('data/cosmetics'):
        c, subs, _ = resource(f)
        req = fields(subs['req']) if 'req' in subs and 'requirement' in c else {}
        d['cosmetics'].append({'id': c['id'], 'name': c.get('display_name', ''), 'slot': c.get('slot', 'weapon_finish'),
                               'rarity': c.get('rarity', 0), 'price': c.get('price', 0), 'kind': req.get('kind', 0),
                               'target': req.get('target', ''), 'amount': req.get('amount', 0),
                               'multi': sum(1 for s in subs if s.startswith('req')) > 1})
    d['milestones'] = [resource(f)[0] for f in listing('data/progression/challenges')]
    d['contracts'] = sorted((resource(f)[0] for f in listing('data/progression/contracts')), key=lambda c: c.get('sort_order', 0))
    return d


# ---- formulas (mirroring the game) -----------------------------------------------
def gd_round(x):
    return int(math.floor(x + 0.5))


def level_table(d, cap):
    r = d['rules']
    table = [0, 0]
    for lvl in range(1, cap):
        k = lvl - 1
        raw = r['level_base_xp'] + r['level_step_xp'] * k + r.get('level_curve_xp', 0) * k * k
        table.append(table[-1] + gd_round(raw / 50.0) * 50)
    return table    # table[L] = total XP to reach level L


def level_for(table, xp):
    lvl = 1
    while lvl + 1 < len(table) and xp >= table[lvl + 1]:
        lvl += 1
    return lvl


def rank_for(curve, xp):
    return sum(1 for t in curve['rank_xp'] if xp >= t)


def level_sparks(eco, lvl):
    if not eco:
        return 0
    bonus = eco['milestone_sparks'] if eco['milestone_every'] and lvl % eco['milestone_every'] == 0 else 0
    return eco['level_sparks_base'] + eco['level_sparks_per_level'] * lvl + bonus


def rank_sparks(eco, rank):
    return eco['rank_sparks_base'] + eco['rank_sparks_per_rank'] * rank if eco else 0


def play(d, level_index, victory):
    """One run of the typical player: stats, score, XP parts, Sparks parts, mastery pool."""
    lv = d['levels'][level_index]
    ws, eco, rules, curve = lv['set'], d['eco'], d['rules'], d['curve']
    waves = lv['waves'] if victory else lv['waves'][:DEFEAT_WAVE]
    cleared = len(waves) if victory else DEFEAT_WAVE - 1
    kills = base_score = tickets = mastery = heavy = kill_sparks = 0.0
    for n, wave in enumerate(waves, 1):
        share = 1.0 if n <= cleared else 0.5
        for eid, count in wave.items():
            e = d['enemies'][eid]
            c = count * share
            kills += c
            base_score += c * e['score']
            tickets += c * e['tickets']
            mastery += c * e['xp']
            heavy += c if e.get('heavy') else 0
            if eco:
                kill_sparks += c * max(1, gd_round(e['tickets'] * eco['sparks_per_kill_ticket']))
    heads = kills * HEADSHOT_RATE
    multis = kills * MULTI_RATE
    longs = kills * LONGSHOT_RATE
    flawless = min(FLAWLESS_WAVES, cleared)
    left = (ws.get('starting_tickets', 100) + tickets) * TICKETS_KEPT if victory else 0
    score = base_score * (1 + 0.5 * HEADSHOT_RATE) * COMBO_MULT + multis * 100 + longs * 50 + CLOSE_CALLS[victory] * 75
    score += sum(100 * n * (2 if n <= flawless else 1) for n in range(1, cleared + 1))
    score += left * ws.get('ticket_score_rate', 5)
    xp = {'Score': score * rules['score_xp_rate'],
          'Wave bonuses': sum(rules['wave_xp_base'] + rules['wave_xp_per_wave'] * n for n in range(1, cleared + 1))}
    sparks = {}
    if victory:
        xp['Level clear'] = rules['clear_xp'] + rules['clear_xp_per_world'] * level_index
    if eco:
        sparks = {'Zombies popped': kill_sparks, 'Headshots': heads * eco['headshot_sparks'],
                  'Combo bonuses': COMBO_TENS[victory] * eco['combo_sparks'],
                  'Waves cleared': cleared * eco['wave_sparks'] + flawless * eco['flawless_wave_sparks']}
        if victory:
            sparks['Level clear'] = eco['clear_sparks'] + eco['clear_sparks_per_world'] * level_index
            sparks['Tickets cashed'] = math.floor(left * eco['sparks_per_ticket'])
    mastery += heads / max(kills, 1) * mastery * curve.get('headshot_bonus', 0.5) + multis * curve.get('multi_kill_bonus', 12) + longs * curve.get('longshot_bonus', 10)
    wave_mastery = sum(ws.get('wave_bonus_base', 20) + ws.get('wave_bonus_per_wave', 5) * n for n in range(1, cleared + 1))
    stats = {'kills': kills, 'headshots': heads, 'multi_kills': multis, 'longshots': longs, 'close_calls': CLOSE_CALLS[victory],
             'heavy_kills': heavy, 'flawless_waves': flawless, 'waves': cleared, 'clears': 1 if victory else 0,
             'healthy_clears': 1 if victory else 0, 'best_combo': BEST_COMBO[victory], 'run_score': score,
             'sparks': kill_sparks + heads * eco.get('headshot_sparks', 0) if eco else 0}
    return {'level': lv, 'victory': victory, 'stats': stats, 'score': score, 'xp': xp, 'sparks': sparks,
            'mastery': mastery, 'wave_mastery': wave_mastery}


class Player:
    def __init__(self, d, cap):
        self.d, self.cap = d, cap
        self.table = level_table(d, cap)
        self.xp = 0
        self.wallet = 0
        self.earned = {}
        self.mastery = {w['id']: 0.0 for w in d['weapons']}
        self.cleared = []
        self.totals = {}
        self.done = set()
        self.contracts = []
        self.contract_cursor = 0
        self.main_cursor = 0
        self.runs = self.clears = 0
        self.spent = 0
        self.kills = 0

    def level(self):
        return level_for(self.table, self.xp)

    def unlocked(self):
        return [w for w in self.d['weapons'] if w['level'] <= self.level()]

    def earn(self, label, amount):
        amount = int(amount)
        self.wallet += amount
        self.earned[label] = self.earned.get(label, 0) + amount
        return amount

    def deal(self):
        pool = [c for c in self.d['contracts'] if c.get('param', 0) <= self.level()]
        while pool and len(self.contracts) < 3:
            active = {c['id'] for c, _ in self.contracts}
            stats = {c['stat'] for c, _ in self.contracts}
            for _ in range(len(pool)):
                c = pool[self.contract_cursor % len(pool)]
                self.contract_cursor += 1
                if c['id'] not in active and c['stat'] not in stats:
                    break
            if c['id'] in active:
                break
            self.contracts.append([c, 0.0])

    def run(self, level_index, victory):
        d, eco, curve = self.d, self.d['eco'], self.d['curve']
        r = play(d, level_index, victory)
        lv = r['level']
        before_level = self.level()
        row = {'level': lv['name'], 'victory': victory, 'unlocks': [], 'sparks': 0}
        xp = dict(r['xp'])
        sparks_before = self.wallet
        first = victory and lv['id'] not in self.cleared
        if first:
            self.cleared.append(lv['id'])
            xp['First clear'] = d['rules']['first_clear_xp']
            row['unlocks'] += [c['name'] for c in d['cosmetics'] if c['kind'] == 2 and c['target'] == lv['id'] and not c['price'] and not c['multi']]
        for label, amount in r['sparks'].items():
            self.earn(label, amount)
        if first and eco:
            self.earn('First clear', eco['first_clear_sparks'])
        # contracts (three at a time, replaced when the run ends) and milestones
        self.deal()
        weapons = self.unlocked()
        main = weapons[self.main_cursor % len(weapons)]
        second = weapons[(self.main_cursor - 1) % len(weapons)] if len(weapons) > 1 else main
        self.main_cursor += 1
        contract_mastery = 0
        for entry in self.contracts:
            c = entry[0]
            sample = r['stats'].get(c['stat'], 0) * (MAIN_SHARE if c.get('scope') == 1 else 1.0)
            entry[1] = max(entry[1], sample) if c.get('mode') == 1 else entry[1] + sample
            if entry[1] >= c['goal']:
                xp['Contracts'] = xp.get('Contracts', 0) + c['xp']
                self.earn('Contracts', c.get('sparks', 0))
                contract_mastery += c.get('mastery_xp', 0) if c.get('scope') == 1 else 0
        self.contracts = [e for e in self.contracts if e[1] < e[0]['goal']]
        old_mastery = dict(self.mastery)
        pool = r['mastery']
        self.mastery[main['id']] += pool * MAIN_SHARE + r['wave_mastery'] + contract_mastery
        if second is not main:
            self.mastery[second['id']] += pool * (1 - MAIN_SHARE) + r['wave_mastery']
        for m in d['milestones']:
            key = m['id']
            if key in self.done:
                continue
            if m.get('scope') == 1:       # the old per-weapon challenges: main weapon only
                key = m['id'] + '@' + main['id']
                if key in self.done:
                    continue
            if m['stat'] == 'max_rank':
                v = max(rank_for(curve, x) for x in self.mastery.values())
            elif m['stat'] == 'weapons_at_rank':
                v = sum(1 for x in self.mastery.values() if rank_for(curve, x) >= m.get('param', 0))
            else:
                sample = r['stats'].get(m['stat'], 0) * (MAIN_SHARE if m.get('scope') == 1 else 1.0)
                v = max(self.totals.get(key, 0), sample) if m.get('mode') == 1 else self.totals.get(key, 0) + sample
            self.totals[key] = v
            if v >= m['goal']:
                self.done.add(key)
                xp['Milestones'] = xp.get('Milestones', 0) + m['xp']
                self.earn('Milestones', m.get('sparks', 0))
                if m.get('scope') == 1:
                    self.mastery[main['id']] += m.get('mastery_xp', 0)
                row['unlocks'] += [c['name'] for c in d['cosmetics'] if c['kind'] == 20 and c['target'] == m['id']]
        self.xp += sum(xp.values())
        # mastery ranks, kills and levels reached
        ranks = []
        for w in d['weapons']:
            a, b = rank_for(curve, old_mastery[w['id']]), rank_for(curve, self.mastery[w['id']])
            for rank in range(a + 1, b + 1):
                self.earn('Mastery ranks', rank_sparks(eco, rank))
            if b > a:
                ranks.append('%s r%d' % (w['name'].split()[0], b))
        kills_before = self.kills
        self.kills += r['stats']['kills']
        row['unlocks'] += [c['name'] for c in d['cosmetics'] if c['kind'] == 4 and not c['price'] and kills_before < c['amount'] <= self.kills]
        after = self.level()
        for lvl in range(before_level + 1, after + 1):
            self.earn('Level-ups', level_sparks(eco, lvl))
            row['unlocks'] += [w['name'] for w in d['weapons'] if w['level'] == lvl]
            row['unlocks'] += [c['name'] for c in d['cosmetics'] if c['kind'] == 1 and c['amount'] == lvl and not c['price']]
        self.runs += 1
        self.clears += 1 if victory else 0
        row.update(xp=int(sum(xp.values())), lvl=after, lvl_ups=after - before_level, ranks=ranks,
                   sparks=self.wallet - sparks_before, wallet=self.wallet, main=main['name'])
        return row


def schedule(d, n):
    """(level index, victory) for run n: worlds in order, then cycling; SESSION pattern."""
    plan, cleared, cycle = [], 0, 0
    worlds = len(d['levels'])
    for i in range(n):
        victory = SESSION[i % len(SESSION)]
        if cleared < worlds:
            index = cleared
            if victory:
                cleared += 1
        else:
            index = cycle % worlds
            cycle += 1 if victory else 0
        plan.append((index, victory))
    return plan


def afford(d, sparks):
    ladder = d['eco'].get('prices') if d['eco'] else None
    if not ladder:
        return '-'
    names = ['common', 'rare', 'epic', 'legendary']
    best = [n for n, p in zip(names, ladder) if p and sparks >= p]
    if not best:
        return 'nothing yet'
    top = best[-1]
    count = sparks // ladder[names.index(top)]
    return '%d %s' % (count, top if count == 1 else top.replace('legendary', 'legendarie') + 's')


def afford_goals(d, shop):
    """(name, price): the ladder price of each rarity, then the showpiece prices in use."""
    eco = d['eco'] or {}
    ladder = eco.get('prices') or []
    premium = [p for p in (eco.get('premium_prices') or []) if p]
    goals = [(n, p) for n, p in zip(['common', 'rare', 'epic', 'legendary'], ladder) if p]
    prices = {c['price'] for c in shop}
    goals += [('showpiece', p) for p in sorted(set(premium) & prices)]
    return goals


def table(rows, header, markdown):
    if markdown:
        print('| ' + ' | '.join(header) + ' |')
        print('|' + '|'.join(' --- ' for _ in header) + '|')
        for r in rows:
            print('| ' + ' | '.join(str(c) for c in r) + ' |')
        return
    widths = [max(len(str(r[i])) for r in rows + [header]) for i in range(len(header))]
    for r in [header] + rows:
        print('  '.join(str(c).ljust(w) for c, w in zip(r, widths)).rstrip())


def main():
    global REV
    runs_shown, markdown = 15, False
    for a in sys.argv[1:]:
        if a.startswith('--rev='):
            REV = a.split('=', 1)[1]
        elif a.startswith('--runs='):
            runs_shown = int(a.split('=', 1)[1])
        elif a == '--markdown':
            markdown = True
    d = load()
    eco = d['eco']
    cap = 40 if eco else 50
    p = Player(d, cap)
    plan = schedule(d, 400)
    rows, cap_run, cap_clear, all_weapons = [], None, None, None
    history, at_cap = [], {}
    shop = [c for c in d['cosmetics'] if c['price']]
    shop_total = sum(c['price'] for c in shop)
    shop_run = shop_clear = None
    goals = afford_goals(d, shop)
    reached = {}
    for i, (index, victory) in enumerate(plan, 1):
        row = p.run(index, victory)
        if i <= runs_shown:
            unlocks = row['unlocks'] + row['ranks']
            shown = ', '.join(unlocks[:4]) + (' +%d more' % (len(unlocks) - 4) if len(unlocks) > 4 else '')
            rows.append([i, row['level'], 'clear' if victory else 'defeat w%d' % DEFEAT_WAVE, row['xp'],
                         '%d%s' % (row['lvl'], ' (+%d)' % row['lvl_ups'] if row['lvl_ups'] else ''),
                         row['sparks'] if eco else '-', row['wallet'] if eco else '-', afford(d, row['sparks']), shown])
        if all_weapons is None and len(p.unlocked()) == len(d['weapons']):
            all_weapons = (i, p.clears)
        if cap_run is None and p.level() >= cap:
            cap_run, cap_clear = i, p.clears
            at_cap = dict(p.earned)
        for name, price in goals:
            if (name, price) not in reached and p.wallet >= price:
                reached[(name, price)] = i
        if shop and shop_run is None and p.wallet >= shop_total:
            shop_run, shop_clear = i, p.clears
        history.append((victory, row['sparks']))
    print('== %s: %s ==' % ('Data at ' + REV if REV else 'Current data', 'no currency' if not eco else 'Sparks economy'))
    print()
    table(rows, ['Run', 'Level', 'Result', 'XP', 'Player level', 'Sparks', 'Saved (if unspent)', 'The run buys', 'Unlocks'], markdown)
    print()
    # one weapon as a main: runs to max rank (clears of the world cycle, main share of the kills)
    curve = d['curve']
    xp = runs = 0
    first_run_rank = None
    while rank_for(curve, xp) < len(curve['rank_xp']) and runs < 200:
        r = play(d, runs % len(d['levels']), True)
        xp += r['mastery'] * MAIN_SHARE + r['wave_mastery']
        runs += 1
        if first_run_rank is None:
            first_run_rank = rank_for(curve, xp)
    totals = [['Level cap', cap],
              ['XP to the cap', '{:,}'.format(p.table[cap])],
              ['Clears to the cap (typical player)', '%s (%s runs)' % (cap_clear, cap_run)],
              ['All %d weapons unlocked after' % len(d['weapons']), '%s clears (%s runs), at level %d' % (all_weapons[1], all_weapons[0], max(w['level'] for w in d['weapons']))],
              ['Level-ups in the first session (3 runs)', rows[2][4].split()[0] + ' reached' if len(rows) > 2 else '-'],
              ['Mastery: rank after the first run as a main', first_run_rank],
              ['Mastery: runs as a main to rank %d' % len(curve['rank_xp']), runs],
              ['Goals on the Career page', '%d' % (sum(len(d['weapons']) if m.get('scope') == 1 else 1 for m in d['milestones']) + (3 if d['contracts'] else 0))]]
    if eco:
        earned = sum(at_cap.values())
        totals += [['Sparks earned by the cap', '{:,}'.format(earned)],
                   ['Items for sale', '%d, %s Sparks in total' % (len(shop), '{:,}'.format(shop_total))],
                   ['Clears to buy everything', '%s (%s runs)' % (shop_clear, shop_run)],
                   ['Sparks per session of 3 runs: first five sessions / after the cap', '%d / %d' % (
                       sum(x for _, x in history[:15]) / 5, sum(x for _, x in history[cap_run:cap_run + 30]) / 10)],
                   ['Sparks per run: first 15 runs / after the cap', '%d / %d' % (
                       sum(x for _, x in history[:15]) / 15, sum(x for _, x in history[cap_run:cap_run + 30]) / 30)],
                   ['Runs of saving (new profile) to afford a', ', '.join(
                       '%s %s: %s' % (name, '{:,}'.format(price), reached.get((name, price), '-')) for name, price in goals)],
                   ['Where Sparks come from (up to the cap)', ', '.join('%s %d%%' % (k, round(100.0 * v / earned)) for k, v in sorted(at_cap.items(), key=lambda kv: -kv[1]) if v * 100 >= earned)]]
    table(totals, ['Totals', ''], markdown)
    if eco:
        print()
        by = {}
        for c in shop:
            by.setdefault(c['slot'], []).append(c['price'])
        table([[slot, len(v), '{:,}'.format(sum(v))] for slot, v in sorted(by.items(), key=lambda kv: -sum(kv[1]))], ['Shop section', 'Items', 'Sparks'], markdown)
        print()
        track = []
        for lvl in range(2, cap + 1):
            what = [w['name'] + ' (weapon)' for w in d['weapons'] if w['level'] == lvl] + [c['name'] for c in d['cosmetics'] if c['kind'] == 1 and c['amount'] == lvl and not c['price']]
            track.append([lvl, '{:,}'.format(p.table[lvl]), level_sparks(eco, lvl), ', '.join(what) or '(nothing!)'])
        table(track, ['Level', 'Total XP', 'Sparks', 'Reward'], markdown)


if __name__ == '__main__':
    main()

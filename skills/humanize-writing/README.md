# Humanize Writing

A prompt-based writing editor that rewrites AI-generated text to sound like a real human wrote it.

It catches the patterns that make AI writing obvious — the vocabulary, the sentence structures, the too-perfect tone — and fixes them through a systematic 3-pass editing process.

Works with **any LLM**: Claude, ChatGPT, Gemini, Cursor, Windsurf, or anything that accepts a system prompt. Also available as a one-command install for Claude Code users.

## How It Works

The system runs your text through three passes:

**Pass 1: Kill the AI Vocabulary** — Replaces words like "delve," "leverage," "tapestry," and 30+ other statistically overused AI words with simpler human alternatives.

**Pass 2: Break the AI Structures** — Eliminates structural patterns like parallel negation ("Not X, but Y"), tricolons (groups of three), em dash overuse, rhetorical Q+A, and mirror structures. These are stronger tells than vocabulary.

**Pass 3: Add Human Texture** — Varies sentence length, adds contractions, lets some thoughts stay unresolved, and makes the author's actual opinion visible.

Also includes special rules for LinkedIn posts and a 14-point quality checklist that runs before returning any rewrite.

## Quick Start (Any LLM)

The entire system is three markdown files. You can use them right now:

1. **[SKILL.md](skills/humanize-writing/SKILL.md)** — The main instructions (the 3-pass process, LinkedIn rules, quality checklist)
2. **[ai-patterns-dictionary.md](skills/humanize-writing/references/ai-patterns-dictionary.md)** — The reference dictionary (36+ banned words, 10 structural patterns, tone tells)
3. **[voices.md](skills/humanize-writing/references/voices.md)** — The voice definitions (four preset voices, plus a mirror mode for matching the user's own writing)

Copy the contents of all three files into your LLM's system prompt or custom instructions, then paste any text you want humanized.

## What's Inside

```
skills/humanize-writing/
├── SKILL.md                              # 3-pass rewriting process + quality checklist
└── references/
    ├── ai-patterns-dictionary.md         # Banned words, structural patterns, tone tells
    └── voices.md                         # Voice presets for Pass 3 (tone, rhythm, signature qualities)
```

### The AI Patterns Dictionary Covers

- **Tier 1 Banned Words** (18 words) — Strongest AI signals like "delve," "tapestry," "pivotal," "testament"
- **Tier 2 Banned Words** (18 words) — Moderate signals like "crucial," "leverage," "seamless," "robust"
- **Tier 3 Transitions** — Words that are fine alone but AI clusters unnaturally ("Furthermore," "Moreover," "Additionally")
- **10 Structural Patterns** — Parallel negation, tricolons, em dash overuse, rhetorical Q+A, mirror structures, dramatic reveals, and more
- **Tone & Voice Tells** — Uniform sentence length, hedging, over-positivity, absence of personal voice
- **Content Red Flags** — Generic conclusions, missing concrete details, regression to generic statements

## Writing Philosophy

Based on the principles behind Paul Graham's writing style: clarity over cleverness, directness over decoration. Good writing sounds like a smart person thinking out loud. The goal is invisible editing — the reader should never think about *how* something was written.

## Sources

The AI patterns dictionary draws from:

- [Wikipedia: Signs of AI Writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)
- [GPTZero AI Vocabulary Research](https://gptzero.me/ai-vocabulary)
- [Chris Herbert's ChatGPT Overused Words](https://gist.github.com/chrisgherbert/c734ec50ae464135be57cd03b84281f9)
- [Sabrina Ramonov's Humanizer Prompt](https://github.com/SabrinaRamonov/prompts/blob/main/humanize_ai_writing.md)
- [God of Prompt: 500 ChatGPT Overused Words](https://www.godofprompt.ai/blog/500-chatgpt-overused-words-heres-how-to-avoid-them)

## License

MIT

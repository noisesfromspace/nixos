#!/usr/bin/env node
import fetch from "node-fetch";

async function ddgSearch(query, limit = 5) {
  const res = await fetch(
    `https://duckduckgo.com/html/?q=${encodeURIComponent(query)}`,
    { headers: { "User-Agent": "Mozilla/5.0" } }
  );

  const html = await res.text();

  return [...html.matchAll(
    /<a rel="nofollow" class="result__a" href="(.*?)">(.*?)<\/a>/g
  )]
    .slice(0, limit)
    .map(m => ({
      url: decodeURIComponent(m[1]),
      title: m[2].replace(/<[^>]+>/g, ""),
    }));
}

async function fetchClean(url) {
  try {
    const res = await fetch(`https://r.jina.ai/${url}`);
    return (await res.text()).slice(0, 4000);
  } catch {
    return null;
  }
}

async function main() {
  const query = process.argv.slice(2).join(" ");
  if (!query) {
    console.error("Usage: ddg-search <query>");
    process.exit(1);
  }

  const results = await ddgSearch(query, 5);
  const pages = await Promise.all(results.map(r => fetchClean(r.url)));

  const context = pages.filter(Boolean).join("\n\n---\n\n");

  console.log("\n=== SOURCES ===");
  results.forEach(r => console.log(r.url));

  console.log("\n=== CONTEXT (truncated) ===\n");
  console.log(context.slice(0, 2000));
}

main();

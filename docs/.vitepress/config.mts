import { defineConfig } from "vitepress";

// Site configuration
export const SITE_URL = "https://muhammad-fiaz.github.io/args.zig";
export const SITE_NAME = "args.zig";
export const SITE_DESCRIPTION = "A fast, powerful, and developer-friendly command-line argument parsing library for Zig with Python argparse-inspired API, shell completions, environment variables, and subcommands.";

// Google Analytics and Google Tag Manager IDs
export const GA_ID = "G-6BVYCRK57P";
export const GTM_ID = "GTM-P4M9T8ZR";

// Google AdSense Client ID
export const ADSENSE_CLIENT_ID = "ca-pub-2040560600290490";

// SEO Keywords
export const KEYWORDS = "zig, argument parser, cli, command line, argparse, shell completions, bash completion, zsh completion, fish completion, powershell completion, environment variables, subcommands, zig library, cli parsing";

export default defineConfig({
  lang: "en-US",
  title: SITE_NAME,
  description: SITE_DESCRIPTION,
  base: "/args.zig/",
  lastUpdated: true,
  cleanUrls: true,

  sitemap: {
    hostname: SITE_URL,
  },

  head: [
    ["meta", { name: "viewport", content: "width=device-width, initial-scale=1.0" }],
    ["meta", { name: "google-adsense-account", content: ADSENSE_CLIENT_ID }],
    // Primary Meta Tags
    ["meta", { name: "title", content: SITE_NAME }],
    ["meta", { name: "description", content: SITE_DESCRIPTION }],
    ["meta", { name: "keywords", content: KEYWORDS }],
    ["meta", { name: "author", content: "Muhammad Fiaz" }],
    ["meta", { name: "robots", content: "index, follow" }],
    ["meta", { name: "language", content: "English" }],
    ["meta", { name: "revisit-after", content: "7 days" }],
    ["meta", { name: "generator", content: "VitePress" }],

    // Open Graph / Facebook
    ["meta", { property: "og:type", content: "website" }],
    ["meta", { property: "og:url", content: SITE_URL }],
    ["meta", { property: "og:title", content: SITE_NAME }],
    ["meta", { property: "og:description", content: SITE_DESCRIPTION }],
    ["meta", { property: "og:image", content: `${SITE_URL}/cover.png` }],
    ["meta", { property: "og:image:width", content: "1200" }],
    ["meta", { property: "og:image:height", content: "630" }],
    ["meta", { property: "og:image:alt", content: "args.zig - Fast Command-Line Argument Parsing for Zig" }],
    ["meta", { property: "og:site_name", content: SITE_NAME }],
    ["meta", { property: "og:locale", content: "en_US" }],

    // Twitter Card
    ["meta", { name: "twitter:card", content: "summary_large_image" }],
    ["meta", { name: "twitter:url", content: SITE_URL }],
    ["meta", { name: "twitter:title", content: SITE_NAME }],
    ["meta", { name: "twitter:description", content: SITE_DESCRIPTION }],
    ["meta", { name: "twitter:image", content: `${SITE_URL}/cover.png` }],
    ["meta", { name: "twitter:creator", content: "@muhammadfiaz_" }],

    // Canonical URL
    ["link", { rel: "canonical", href: SITE_URL }],

    // JSON-LD Schema for Software Application
    [
      "script",
      { type: "application/ld+json" },
      JSON.stringify({
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "args.zig",
        "applicationCategory": "DeveloperApplication",
        "operatingSystem": "Cross-platform",
        "programmingLanguage": "Zig",
        "offers": {
          "@type": "Offer",
          "price": "0",
          "priceCurrency": "USD"
        },
        "author": {
          "@type": "Person",
          "name": "Muhammad Fiaz",
          "url": "https://github.com/muhammad-fiaz"
        },
        "description": SITE_DESCRIPTION,
        "url": SITE_URL,
        "downloadUrl": "https://github.com/muhammad-fiaz/args.zig",
        "softwareVersion": "0.0.2",
        "license": "https://opensource.org/licenses/MIT"
      })
    ],

    // JSON-LD Schema for Documentation
    [
      "script",
      { type: "application/ld+json" },
      JSON.stringify({
        "@context": "https://schema.org",
        "@type": "TechArticle",
        "headline": "args.zig Documentation",
        "description": SITE_DESCRIPTION,
        "author": {
          "@type": "Person",
          "name": "Muhammad Fiaz"
        },
        "publisher": {
          "@type": "Person",
          "name": "Muhammad Fiaz"
        },
        "mainEntityOfPage": {
          "@type": "WebPage",
          "@id": SITE_URL
        },
        "image": `${SITE_URL}/cover.png`
      })
    ],

    // JSON-LD Schema for Organization
    [
      "script",
      { type: "application/ld+json" },
      JSON.stringify({
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": "Muhammad Fiaz",
        "url": "https://github.com/muhammad-fiaz",
        "logo": `${SITE_URL}/logo.png`,
        "sameAs": [
          "https://github.com/muhammad-fiaz",
          "https://twitter.com/muhammadfiaz_"
        ]
      })
    ],

    // Favicons
    ["link", { rel: "icon", href: "/args.zig/favicon.ico" }],
    ["link", { rel: "icon", type: "image/png", sizes: "16x16", href: "/args.zig/favicon-16x16.png" }],
    ["link", { rel: "icon", type: "image/png", sizes: "32x32", href: "/args.zig/favicon-32x32.png" }],
    ["link", { rel: "apple-touch-icon", sizes: "180x180", href: "/args.zig/apple-touch-icon.png" }],
    ["link", { rel: "icon", type: "image/png", sizes: "192x192", href: "/args.zig/android-chrome-192x192.png" }],
    ["link", { rel: "icon", type: "image/png", sizes: "512x512", href: "/args.zig/android-chrome-512x512.png" }],
    ["link", { rel: "manifest", href: "/args.zig/site.webmanifest" }],

    // Theme color
    ["meta", { name: "theme-color", content: "#f7a41d" }],
    ["meta", { name: "msapplication-TileColor", content: "#f7a41d" }],

    // Google Analytics (gtag.js)
    [
      "script",
      { async: "", src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}` },
    ],
    [
      "script",
      {},
      `window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '${GA_ID}');`,
    ],

    // Google Tag Manager
    ...(GTM_ID
      ? ([
          [
            "script",
            {},
            `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start': new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0], j=d.createElement(s), dl=l!='dataLayer'?'&l='+l:''; j.async=true; j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl; f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','${GTM_ID}');`,
          ],
          [
            "noscript",
            {},
            `<iframe src="https://www.googletagmanager.com/ns.html?id=${GTM_ID}" height="0" width="0" style="display:none;visibility:hidden"></iframe>`,
          ],
        ] as [string, Record<string, string>, string][])
      : []),
    
    // Google AdSense
    [
      "script",
      {
        async: "",
        src: `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`,
        crossorigin: "anonymous",
      },
    ],
  ],

  ignoreDeadLinks: [/.*\.zig$/],

  transformPageData(pageData) {
    const pageTitle = pageData.title || SITE_NAME;
    const pageDescription = pageData.frontmatter?.description || SITE_DESCRIPTION;
    const canonicalUrl = `${SITE_URL}/${pageData.relativePath.replace(/\.md$/, '.html').replace(/index\.html$/, '')}`;

    pageData.frontmatter.head ??= [];
    
    // Add canonical and OG tags for each page
    pageData.frontmatter.head.push(
      ["link", { rel: "canonical", href: canonicalUrl }],
      ["meta", { property: "og:title", content: `${pageTitle} | ${SITE_NAME}` }],
      ["meta", { property: "og:url", content: canonicalUrl }],
      ["meta", { property: "og:description", content: pageDescription }],
      ["meta", { property: "og:image", content: `${SITE_URL}/cover.png` }],
      ["meta", { name: "twitter:title", content: `${pageTitle} | ${SITE_NAME}` }],
      ["meta", { name: "twitter:description", content: pageDescription }],
      ["meta", { name: "twitter:image", content: `${SITE_URL}/cover.png` }],
      ["meta", { name: "description", content: pageDescription }]
    );
  },

  themeConfig: {
    logo: "/logo.png",
    siteTitle: "args.zig",

    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/getting-started" },
      { text: "API", link: "/api/parser" },
      { text: "Examples", link: "/examples/" },
      {
        text: "Support",
        items: [
          { text: "💖 Sponsor", link: "https://github.com/sponsors/muhammad-fiaz" },
          { text: "☕ Donate", link: "https://pay.muhammadfiaz.com" },
        ],
      },
      { text: "GitHub", link: "https://github.com/muhammad-fiaz/args.zig" },
    ],

    sidebar: {
      "/guide/": [
        {
          text: "Getting Started",
          items: [
            { text: "Introduction", link: "/guide/introduction" },
            { text: "Installation", link: "/guide/installation" },
            { text: "Quick Start", link: "/guide/getting-started" },
            { text: "Options & Flags", link: "/guide/options-flags" },
            { text: "Subcommands", link: "/guide/subcommands" },
          ],
        },
        {
          text: "Advanced",
          items: [
            { text: "Environment Variables", link: "/guide/environment-variables" },
            { text: "Argument Groups", link: "/guide/groups" },
            { text: "Validation", link: "/guide/validation" },
            { text: "Shell Completions", link: "/guide/shell-completions" },
            { text: "Efficiency & Utilities", link: "/guide/efficiency" },
            { text: "Configuration", link: "/guide/configuration" },
            { text: "Update Checker", link: "/guide/updates" },
          ],
        },
      ],
      "/api/": [
        {
          text: "API Reference",
          items: [
            { text: "Parser", link: "/api/parser" },
            { text: "Types", link: "/api/types" },
            { text: "Errors", link: "/api/errors" },
          ],
        },
      ],
      "/examples/": [
        {
          text: "Examples",
          items: [
            { text: "All Examples", link: "/examples/" },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: "github", link: "https://github.com/muhammad-fiaz/args.zig" },
    ],

    footer: {
      message: "Released under the MIT License.",
      copyright: "Copyright © 2025 Muhammad Fiaz",
    },

    search: {
      provider: "local",
    },

    editLink: {
      pattern: "https://github.com/muhammad-fiaz/args.zig/edit/main/docs/:path",
      text: "Edit this page on GitHub",
    },

    lastUpdated: {
      text: "Last updated",
      formatOptions: {
        dateStyle: "medium",
        timeStyle: "short",
      },
    },
  },
});

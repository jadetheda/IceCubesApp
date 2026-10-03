Title: Live Content

Description: Fetched live

Source: https://exa.y2k.diy/garden/pluraldawn

---

<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<meta name="darkreader-lock">
		<link rel="icon" href="/logo.svg" type="image/svg+xml">
		<title>Pluraldawn — Exa's Corner</title>
		<style>
		/* not HTML so that it doesn't FOUC when 11ty hotswaps */
		@import url(https://fonts.bunny.net/css?family=fira-mono:400,700|fira-sans:400,400i,700,700i|fira-sans-condensed:300);
		</style>
		<noscript><style>.yesscript{display:none!important}.pronounce{color:inherit;text-decoration:none;svg{display:none}}</style></noscript>
		<link rel="stylesheet" id="mainstyle" href="/static/garden.css">
		<link rel="stylesheet" href="/static/syntax.css">
		<meta name="generator" content="Eleventy v3.0.0">
		<meta property="twitter:card" content="summary"/>
		<meta property="twitter:title" content="Pluraldawn"/>
		<meta property="twitter:description" content="Parse indicator emojis in various Fediverse webapps"/>
		<meta property="og:title" content="Pluraldawn"/>
		<meta property="og:image" content="https://exa.y2k.diy/logo.png"/>
		<meta property="og:type" content="article"/>
		<meta property="og:site_name" content="Exa's Corner"/>
		<meta property="og:description" content="Parse indicator emojis in various Fediverse webapps"/>
		<meta property="og:article:modified_time" content="2026-09-20T00:22:58.001Z"/>
		<meta property="og:article:section" content="Projects"/>
		<meta property="og:url" content="https://exa.y2k.diy/garden/pluraldawn/"/>
		<link rel="canonical" href="https://exa.y2k.diy/garden/pluraldawn/"/>
		<script defer src="/static/anti-fouc.js"></script>
		<script defer src="/static/immut/temporal-polyfill.js"></script>
		<script defer src="/static/time.js"></script>
	<script type="module" src="/.11ty/reload-client.js"></script></head>
	<body class="">
		<a class="ct" href="/newsitetmp/pluraldawn">CLICK HERE FOR INFINITE DELECTABLE CONTENT</a>
		<article>
	<h1>Pluraldawn <time class="page-update yesscript" data-url="/garden/pluraldawn/" datetime="2026-09-20T00:22:58.001Z"></time></h1>
	<nav>
		<a href="/">« Return to index</a>
		<div id="view-source-outer"><input type="checkbox" name="view-source" id="view-source"> <label for="view-source">View source</label></div>
	</nav>
	
	
	
	<main>
		<p author="una">Pluraldawn is a userscript for Mastodon Web, Akkoma, Wafrn, and Misskey (more frontends coming soon probably) that parses indicator emojis in posts, and uses a set of rules read from user avatar data to change the post’s avatar and display name.</p>
<p>Here’s a demonstration:</p>
<figure><p><img alt="" src="[IMAGE REDACTED]"></p>
<figcaption><p><span class="small">Before</span></p>
</figcaption></figure><figure><p><img alt="" src="[IMAGE REDACTED]"></p>
<figcaption><p><span class="small">After</span></p>
</figcaption></figure><section id="Installation">
<h2>Installation</h2>
<p>The userscript can be installed <a href="https://git.sleeping.town/exa/pluraldawn/raw/branch/trunk/pluraldawn.user.js">from our Forgejo</a>, using any compatible userscript manager.</p>
<div class="warning">
<p><strong>Fair warning</strong>: Due to there not being a way to just know about <em>every fedi server that exists and ever will exist</em>, Pluraldawn runs on <em>all webpages</em>. <strong>This includes things like your bank.</strong> The script will only activate if fedi software is detected, but the script could be modified to not do that by us or an attacker.</p>
<p>Additionally, to bypass CSP/CORS/ServiceWorker restrictions in order to perform raw avatar retrieval, Pluraldawn <em>has permission to quietly make web requests to anywhere, without any security controls</em>. <strong>These requests are invisible even to other extensions, like uBlock or Request Control.</strong></p>
<p>We recommend you read diffs before installing userscript updates, and are trying to find a better way to implement this. (It may be to move to a WebExtension rather than a userscript.)</p>
</div>
<div style="color: var(--green)">
<p>Known <em>working</em> configurations:</p>
<ul>
<li>
Violentmonkey on Desktop Firefox <strong>(recommended)</strong>
</li>
<li>
GreaseMonkey 4 on Desktop Firefox
</li>
<li>
Tampermonkey on Desktop Firefox <strong>(<em>strongly</em> discouraged)</strong>
</li>
<li>
Violentmonkey on Desktop Chromium (requires MV2 extension support)
</li>
<li>
Tampermonkey on Desktop Chromium
</li>
<li>
Violentmonkey on Android Firefox
</li>
<li>
Tampermonkey on Android Firefox
</li>
</ul>
</div>
<p>Safari support is an ongoing question.</p>
<div style="color: var(--red)">
<p>Known <strong>BROKEN</strong> configurations:</p>
<ul>
<li>
Greasemonkey on Android Firefox
<ul>
<li>
Native tab crash early during post parsing. (GM_xmlhttpRequest?)
</li>
</ul>
</li>
<li>
Violentmonkey on Android Cromite
<ul>
<li>
GM_xmlhttpRequest never returns a result due to crashing inside Violentmonkey code
</li>
</ul>
</li>
<li>
Tampermonkey on Android Cromite
<ul>
<li>
Can’t install any scripts, they just don’t save
</li>
</ul>
</li>
</ul>
</div>
<p>Known working frontends:</p>
<ul>
<li>
Mastodon family
<ul>
<li>
Glitch Edition 4.3
</li>
<li>
Glitch Edition 4.2
</li>
<li>
Vanilla 4.3
</li>
<li>
Vanilla 4.6
</li>
<li>
GoToSocial MastoFE 4.3.5
</li>
<li>
GoToSocial MastoFE Next 4.3.5
</li>
<li>
Chuckya 4.6
</li>
</ul>
</li>
<li>
Wafrn 2026.01.05
</li>
<li>
Akkoma FE 2026-01-11
</li>
<li>
Sharkey 2025.4.4
</li>
<li>
Phanpy 2026.06.23
</li>
</ul>
</section>
<section id="Usage">
<h2>Usage</h2>
<p>Pluraldawn parses and removes <strong>indicators</strong>, which can be Unicode, custom emojis, or just plaintext strings — given a set of rules that resembles a PluralKit system if you squint really hard. Indicators are detected in the following situations:</p>
<ul>
<li>
<strong>A prefix</strong>, before all other content of the post, in the first paragraph
</li>
<li>
A lone indicator after <strong>any mention</strong> in the first paragraph of the post (to detect the above inside of a reply)
</li>
<li>
<strong>A suffix</strong>, after all other content of the post, in the last paragraph
</li>
</ul>
<p>If there is ever an ambiguity (i.e. multiple members match the same post), Pluraldawn bails out and does not modify the post. This allows posting of “dialogues” using indicators as normal, but we would instead suggest our other tool <a href="https://utter.y2k.diy">Utter</a> for doing this more naturally.</p>
<p>You can encode data into your avatar in a few ways:</p>
<p><strong>PlDw2 (v2) Encoders</strong>:</p>
<ul>
<li>
<a href="https://yummy.cricket/severals/">severals 2</a>, an encoder+decoder that runs in your web browser with an easy-to-use data editor <strong><strong>(recommended)</strong></strong>
</li>
<li>
<a href="https://git.sleeping.town/exa/pluraldawn/src/branch/trunk/Pldw2Encoder.java">Pldw2Encoder.java</a>, an updated command-line Java reference implementation that encodes PlDw2 format
</li>
</ul>
<p><strong>PlDon (v1) Encoders</strong>:</p>
<ul>
<li>
<a href="https://git.rhiannon.website/rhi/severals">severals 1</a>, command-line encoder+decoder written in Haskell
</li>
<li>
<a href="https://git.sleeping.town/exa/pluraldawn/src/branch/trunk/PldonEncoder.java">PldonEncoder.java</a>, the original command-line Java reference implementation that expects you to write your own JSON/etc
</li>
</ul>
<p>If you’re using a reference encoder, you will need a JSON file like this (an abridged version of our public config):</p>
<pre class="language-json"><code class="language-json"><span class="token punctuation">{</span>
	<span class="token property">"accounts"</span><span class="token operator">:</span> <span class="token punctuation">[</span><span class="token string">"exa@sleeping.town"</span><span class="token punctuation">]</span><span class="token punctuation">,</span>
	<span class="token property">"members"</span><span class="token operator">:</span> <span class="token punctuation">[</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":aesen:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"aesen"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa::Aesen, recurrent dragon"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":snst:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"snst"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa::Sunset, control program"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"monospace"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":una:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"una"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa::Una, technicolor deer"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":kaile:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"kaile"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa::Kaile, aberrant charge"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":lumin:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"lumin"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa::Lumin, metal and phosphor"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":mt_crt_w_noise:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"unknown"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa:???"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://exa.y2k.diy/junk/noise.png"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span>
	<span class="token punctuation">]</span>
<span class="token punctuation">}</span></code></pre><p><span class="small">Order is randomized server-side when this page is recompiled.</span></p>
<p>This data is encoded into our avatar, and automatically parsed out of it by the userscript when it first sees it.</p>
<p>At the top level, two values can be specified:</p>
<ul>
<li>
<code>accounts</code>: An array of strings, specifying the accounts this system information should be used for. <strong>Only useful for specifying custom system data in userscript storage, does nothing when encoded into an avatar!!</strong>
</li>
<li>
<code>members</code>: An array of members, described below.
</li>
</ul>
<p>Every object under the <code>members</code> array must contain exactly four values:</p>
<ul>
<li>
<code>emoji</code>: An array or single value, describing the indicator to match on. Called “emoji” for legacy reasons, can also be a plaintext string signature.
</li>
<li>
<code>id</code>: A string that will be shown after a slash in the modified username.
</li>
<li>
<code>name</code>: A string that will replace the display name. If <code>accounts</code> is specified top-level and this is an array, then the name with the same index in this array as the account being matched will be used.
</li>
<li>
<code>avatar</code>: Either the string “emoji” to use the emoji’s own image (only reliable for custom emojis), or a URL to an avatar. By default, only URLs on the following domains are permitted:
<ul>
<li>
<code>blob.jortage.com</code>
</li>
<li>
<code>pool.jortage.com</code>
</li>
<li>
<code>files.y2k.diy</code>
</li>
<li>
<code>cdn.pluralkit.me</code>
</li>
<li>
<code>cdn.plural.gg</code>
</li>
<li>
<code>scratchupload.xyz</code>
</li>
<li>
<code>scratchupload.org</code>
</li>
</ul>
</li>
<li>
<code>font</code>: Any of the following values:
<ul>
<li>
<code>normal</code>: Normal font rendering, no changes.
</li>
<li>
<code>smallcaps</code>: Small caps font variant. Browser and font specific.
</li>
<li>
<code>small</code>: 85% font scale.
</li>
<li>
<code>monospace</code>: System default monospace font.
</li>
</ul>
</li>
</ul>
<p>This data can also be added into an array called <code>custom-system-data</code> in userscript storage. In Violentmonkey, you can edit this under the “Values” tab when editing the script. This allows configuring the tool for others accounts, or for having private data that isn’t encoded into publicly-visible avatars.</p>
<p><img alt="" src="[IMAGE REDACTED]"></p>
</section>
<section id="Data-Encoding-Scheme-v1-PlDon">
<h2>Data Encoding Scheme (v1 / PlDon)</h2>
<p>The JSON payload is converted to UTF-8, prepended with “PlDon”, and then written into the image starting at the final (bottom-right) pixel, scanning right-to-left, bottom-to-top. Horizontal lines are filled first.</p>
<p>Each byte is split like so:</p>
<p><code><span class="red">RR</span><span class="green">GGG</span><span class="blue">BBB</span></code></p>
<p>So:</p>
<ul>
<li>
The two most-significant bits go into the two least-significant bits of the red channel
</li>
<li>
The three less-significant bits go into the three least-significant bits of the green channel
</li>
<li>
The three least-significant bits go into the three least-significant bits of the blue channel
</li>
</ul>
<p><span class="small">Yes, it would be better to put two bits into green as human eyes are more sensitive to it. I designed this in a fugue late at night. PlDw2 does this.</span></p>
<p>Here’s the full-resolution version of our public avatar, with the data encoded into it:</p>
<p><img alt="" src="https://blob.jortage.com/blob2/K4Tywj2q75RZZOkH/Fh1Wd9xrQKutp_pjgC0UzCZJhJ55VQk6R20UnObtS5O-CUQy1rwx7-e_jD1WSq/a_YFdnfQ.png"></p>
<p>There is a nearly-imperceptible few lines of noise at the bottom. Here’s a 64x64 version (instead of 400x400) that has the same data, resized to be 4x larger:</p>
<p><img alt="" src="[IMAGE REDACTED]"></p>
<p>The gradient at the bottom is noticeably distorted. And again, but on a uniform gray image:</p>
<p><img alt="" src="[IMAGE REDACTED]"></p>
<p>The first few bytes, from the bottom right of the image, with the contrast increased:</p>
<p><img alt="" src="[IMAGE REDACTED]"></p>
<p>If the <code>PlDon</code> marker string is detected, then the rest of the data up until the first NUL <code>00</code> byte will be decoded as UTF-8 and an attempt will be made to parse it as JSON in the above schema. If it looks valid, it will be loaded and used to decorate posts from the account that has the avatar.</p>
</section>
<section id="Data-Encoding-Scheme-v2-PlDw2">
<h2>Data Encoding Scheme (v2 / PlDw2)</h2>
<p>The JSON payload is parsed and converted into a binary stream. This stream is compressed with DEFLATE with the Zlib header, prepended with “PlDw2”, and written into the image starting at the final (bottom-right) pixel, scanning right-to-left, bottom-to-top. Horizontal lines are filled first.</p>
<p>Each byte is split like so:</p>
<p><code><span class="red">RRR</span><span class="green">GG</span><span class="blue">BBB</span></code></p>
<p>So:</p>
<ul>
<li>
The three most-significant bits go into the three least-significant bits of the red channel
</li>
<li>
The two less-significant bits go into the two least-significant bits of the green channel
</li>
<li>
The three least-significant bits go into the three least-significant bits of the blue channel
</li>
</ul>
<p>The compressed binary stream is made up of “groups”, which each define a single kind of value. A group is a series of UTF-8 encoded strings, each value delimited by U+001E RECORD SEPARATOR. A group is finished with U+001D GROUP SEPARATOR in place of the record separator. If a value is itself a list, the individual components of the list are delimited with U+001F UNIT SEPARATOR. The behavior of such list elements outside of the indicator group is presently undefined.</p>
<p>A string value within a group may start with U+0010 DATA LINK ESCAPE, in which case the next byte is to be interpreted as an unsigned index into an array of known prefixes. <strong>Due to this, you cannot decode the entire datastream as UTF-8. The byte following a DLE is not necessarily valid UTF-8!</strong></p>
<p>The groups written, in order, are the IDs, names, indicators, avatars, and fonts. The lack of a group is indicated with U+0004 END OF TRANSMISSION — if this byte is not present after the fifth group, it indicates an extended format that is not defined at this time.</p>
<p>The IDs, names, indicators, and avatar groups are required. The fonts group may be absent, in which case all values are assumed to be <code>normal</code>.</p>
<p><span class="small">Using C0 control codes for their intended purpose in 2026.</span></p>
<p>The avatars group uses the following prefix array:</p>
<pre><code>00. emoji
01. https://files.y2k.diy/
02. https://exa.y2k.diy/junk/noise.png
03. https://pool.jortage.com/
04. https://blob.jortage.com/
05. https://us.pool.jortage.com/
06. https://us.blob.jortage.com/
07. https://cn.pool.jortage.com/
08. https://cn.blob.jortage.com/
09. https://cdn.pluralkit.me/files/
0A. https://cdn.pluralkit.me/
0B. https://cdn.plural.gg/
0C. https://scratchupload.xyz/
0D. https://scratchupload.org/
</code></pre>
<p>The font group uses the following prefix array:</p>
<pre><code>00. normal
01. smallcaps
02. small
03. monospace
</code></pre>
<p>Data is strung together into typed groups in this way to improve compression, as it puts similar data next to eachother in the stream. DEFLATE has a relatively short context window, and this allows the format to take full advantage of it.</p>
<p>Given this sample system data in v1 / PlDon format:</p>
<pre class="language-json"><code class="language-json"><span class="token punctuation">{</span>
	<span class="token property">"members"</span><span class="token operator">:</span> <span class="token punctuation">[</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":zero:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"zero"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"0 Zero | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":one:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"one"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"1 One | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://cdn.pluralkit.me/this-is-not-a-real-url/just-an-example.webp"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"monospace"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":two:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"two"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"2 Two | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"smallcaps"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token punctuation">[</span><span class="token string">":three:"</span><span class="token punctuation">,</span> <span class="token string">"~3"</span><span class="token punctuation">]</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"three"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"3 Three | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://exa.y2k.diy/junk/noise.png"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"small"</span>
		<span class="token punctuation">}</span>
	<span class="token punctuation">]</span>
<span class="token punctuation">}</span></code></pre><p>With hex numbers in square brackets indicating non-printable characters, and newlines as formatting, that would be encoded like so:</p>
<pre><code>zero[1E]one[1E]two[1E]three[1D]
0 Zero | The Numerals[1E]1 One | The Numerals[1E]2 Two | The Numerals[1E]3 Three | The Numerals[1D]
:zero:[1E]:one:[1E]:two:[1E]:three:[1F]~3[1D]
[10][00][1E][10][0A]this-is-not-a-real-url/just-an-example.webp[1E][10][00][1E][10][02][1D]
[10][00][1E][10][03][1E][10][01][1E][10][02][1D]
[04]
</code></pre>
<p>All groups must contain the same number of elements, and they are matched up into member data by index.</p>
</section>
<section id="History">
<h2>History</h2>
<p>This was originally a few hundred lines of LESS that compiled to a 15,000 line CSS file with hundreds of <code>:has</code> rules. The performance was <em>abysmal</em> and made using the Mastodon frontend miserable, but we found it worth it.</p>
<p>After trying to add support for somemany else’s account to that disaster and it <em>outright freezing our browser</em>, I entered a fey mood and implemented the userscript in about 4 hours — an initial prototype that had feature parity with the CSS hack only took 30 minutes. It has none of the performance pitfalls or limitations of the original CSS hack.</p>
<p>See <a href="https://pub.mastodon.sleeping.town/@exa/115998367976937910">the original dev thread</a> for more context and insight.</p>
</section>

	</main>
	<div id="source-code" class="named-code-block">
		<p><code>pluraldawn.dj</code></p>
		<pre class="language-markdown"><code class="language-markdown">---kdl
title "Pluraldawn"
description "Parse indicator emojis in various Fediverse webapps"
<span class="token title important">tags Projects
<span class="token punctuation">---</span></span>

{author=una}
Pluraldawn is a userscript for Mastodon Web, Akkoma, Wafrn, and Misskey (more frontends coming soon probably) that parses indicator emojis in posts, and uses a set of rules read from user avatar data to change the post's avatar and display name.

Here's a demonstration:

::::figure
![][before]

:::figcaption
[Before]{.small}
:::
::::

::::figure
![][after]

:::figcaption
[After]{.small}
:::
::::

<span class="token title important"><span class="token punctuation">##</span> Installation</span>

The userscript can be installed <span class="token url">[<span class="token content">from our Forgejo</span>](<span class="token url">https://git.sleeping.town/exa/pluraldawn/raw/branch/trunk/pluraldawn.user.js</span>)</span>, using any compatible userscript manager.

:::warning
<span class="token italic"><span class="token punctuation">*</span><span class="token content">Fair warning</span><span class="token punctuation">*</span></span>: Due to there not being a way to just know about <span class="token italic"><span class="token punctuation">_</span><span class="token content">every fedi server that exists and ever will exist</span><span class="token punctuation">_</span></span>, Pluraldawn runs on <span class="token italic"><span class="token punctuation">_</span><span class="token content">all webpages</span><span class="token punctuation">_</span></span>. <span class="token italic"><span class="token punctuation">*</span><span class="token content">This includes things like your bank.</span><span class="token punctuation">*</span></span> The script will only activate if fedi software is detected, but the script could be modified to not do that by us or an attacker.

Additionally, to bypass CSP/CORS/ServiceWorker restrictions in order to perform raw avatar retrieval, Pluraldawn <span class="token italic"><span class="token punctuation">_</span><span class="token content">has permission to quietly make web requests to anywhere, without any security controls</span><span class="token punctuation">_</span></span>. <span class="token italic"><span class="token punctuation">*</span><span class="token content">These requests are invisible even to other extensions, like uBlock or Request Control.</span><span class="token punctuation">*</span></span>

We recommend you read diffs before installing userscript updates, and are trying to find a better way to implement this. (It may be to move to a WebExtension rather than a userscript.)
:::

<span class="token code"><span class="token punctuation">```</span><span class="token code-language">=html</span>
<span class="token code-block language-html"><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;</span>div</span> <span class="token special-attr"><span class="token attr-name">style</span><span class="token attr-value"><span class="token punctuation attr-equals">=</span><span class="token punctuation">"</span><span class="token value css language-css"><span class="token property">color</span><span class="token punctuation">:</span> <span class="token function">var</span><span class="token punctuation">(</span>--green<span class="token punctuation">)</span></span><span class="token punctuation">"</span></span></span><span class="token punctuation">></span></span></span>
<span class="token punctuation">```</span></span>

Known <span class="token italic"><span class="token punctuation">_</span><span class="token content">working</span><span class="token punctuation">_</span></span> configurations:

<span class="token list punctuation">*</span> Violentmonkey on Desktop Firefox <span class="token italic"><span class="token punctuation">*</span><span class="token content">(recommended)</span><span class="token punctuation">*</span></span>
<span class="token list punctuation">*</span> GreaseMonkey 4 on Desktop Firefox
<span class="token list punctuation">*</span> Tampermonkey on Desktop Firefox <span class="token italic"><span class="token punctuation">*</span><span class="token content">(_strongly_ discouraged)</span><span class="token punctuation">*</span></span>
<span class="token list punctuation">*</span> Violentmonkey on Desktop Chromium (requires MV2 extension support)
<span class="token list punctuation">*</span> Tampermonkey on Desktop Chromium
<span class="token list punctuation">*</span> Violentmonkey on Android Firefox
<span class="token list punctuation">*</span> Tampermonkey on Android Firefox


<span class="token code"><span class="token punctuation">```</span><span class="token code-language">=html</span>
<span class="token code-block language-html"><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;/</span>div</span><span class="token punctuation">></span></span></span>
<span class="token punctuation">```</span></span>

Safari support is an ongoing question.


<span class="token code"><span class="token punctuation">```</span><span class="token code-language">=html</span>
<span class="token code-block language-html"><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;</span>div</span> <span class="token special-attr"><span class="token attr-name">style</span><span class="token attr-value"><span class="token punctuation attr-equals">=</span><span class="token punctuation">"</span><span class="token value css language-css"><span class="token property">color</span><span class="token punctuation">:</span> <span class="token function">var</span><span class="token punctuation">(</span>--red<span class="token punctuation">)</span></span><span class="token punctuation">"</span></span></span><span class="token punctuation">></span></span></span>
<span class="token punctuation">```</span></span>

Known <span class="token italic"><span class="token punctuation">*</span><span class="token content">BROKEN</span><span class="token punctuation">*</span></span> configurations:

<span class="token list punctuation">*</span> Greasemonkey on Android Firefox

<span class="token code keyword">	* Native tab crash early during post parsing. (GM_xmlhttpRequest?)</span>
<span class="token list punctuation">*</span> Violentmonkey on Android Cromite

<span class="token code keyword">	* GM_xmlhttpRequest never returns a result due to crashing inside Violentmonkey code</span>
<span class="token list punctuation">*</span> Tampermonkey on Android Cromite

<span class="token code keyword">	* Can't install any scripts, they just don't save</span>

<span class="token code"><span class="token punctuation">```</span><span class="token code-language">=html</span>
<span class="token code-block language-html"><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;/</span>div</span><span class="token punctuation">></span></span></span>
<span class="token punctuation">```</span></span>
Known working frontends:

<span class="token list punctuation">*</span> Mastodon family

<span class="token code keyword">	* Glitch Edition 4.3
	* Glitch Edition 4.2
	* Vanilla 4.3
	* Vanilla 4.6
	* GoToSocial MastoFE 4.3.5
	* GoToSocial MastoFE Next 4.3.5
	* Chuckya 4.6</span>

<span class="token list punctuation">*</span> Wafrn 2026.01.05
<span class="token list punctuation">*</span> Akkoma FE 2026-01-11
<span class="token list punctuation">*</span> Sharkey 2025.4.4
<span class="token list punctuation">*</span> Phanpy 2026.06.23

<span class="token title important"><span class="token punctuation">##</span> Usage</span>

Pluraldawn parses and removes <span class="token italic"><span class="token punctuation">*</span><span class="token content">indicators</span><span class="token punctuation">*</span></span>, which can be Unicode, custom emojis, or just plaintext strings — given a set of rules that resembles a PluralKit system if you squint really hard. Indicators are detected in the following situations:

<span class="token list punctuation">*</span> <span class="token italic"><span class="token punctuation">*</span><span class="token content">A prefix</span><span class="token punctuation">*</span></span>, before all other content of the post, in the first paragraph
<span class="token list punctuation">*</span> A lone indicator after <span class="token italic"><span class="token punctuation">*</span><span class="token content">any mention</span><span class="token punctuation">*</span></span> in the first paragraph of the post (to detect the above inside of a reply)
<span class="token list punctuation">*</span> <span class="token italic"><span class="token punctuation">*</span><span class="token content">A suffix</span><span class="token punctuation">*</span></span>, after all other content of the post, in the last paragraph

If there is ever an ambiguity (i.e. multiple members match the same post), Pluraldawn bails out and does not modify the post. This allows posting of "dialogues" using indicators as normal, but we would instead suggest our other tool <span class="token url">[<span class="token content">Utter</span>](<span class="token url">https://utter.y2k.diy</span>)</span> for doing this more naturally.

You can encode data into your avatar in a few ways:

<span class="token italic"><span class="token punctuation">*</span><span class="token content">PlDw2 (v2) Encoders</span><span class="token punctuation">*</span></span>:

<span class="token list punctuation">*</span> <span class="token url">[<span class="token content">severals 2</span>](<span class="token url">https://yummy.cricket/severals/</span>)</span>, an encoder+decoder that runs in your web browser with an easy-to-use data editor <span class="token bold"><span class="token punctuation">**</span><span class="token content">(recommended)</span><span class="token punctuation">**</span></span>
<span class="token list punctuation">*</span> <span class="token url">[<span class="token content">Pldw2Encoder.java</span>](<span class="token url">https://git.sleeping.town/exa/pluraldawn/src/branch/trunk/Pldw2Encoder.java</span>)</span>, an updated command-line Java reference implementation that encodes PlDw2 format

<span class="token italic"><span class="token punctuation">*</span><span class="token content">PlDon (v1) Encoders</span><span class="token punctuation">*</span></span>:

<span class="token list punctuation">*</span> <span class="token url">[<span class="token content">severals 1</span>](<span class="token url">https://git.rhiannon.website/rhi/severals</span>)</span>, command-line encoder+decoder written in Haskell
<span class="token list punctuation">*</span> <span class="token url">[<span class="token content">PldonEncoder.java</span>](<span class="token url">https://git.sleeping.town/exa/pluraldawn/src/branch/trunk/PldonEncoder.java</span>)</span>, the original command-line Java reference implementation that expects you to write your own JSON/etc

If you're using a reference encoder, you will need a JSON file like this (an abridged version of our public config):

{% set options = [0, 1, 2, 3, 4] %}


<span class="token code"><span class="token punctuation">```</span><span class="token code-language">json</span>
<span class="token code-block language-json"><span class="token punctuation">{</span>
	<span class="token property">"accounts"</span><span class="token operator">:</span> <span class="token punctuation">[</span><span class="token string">"exa@sleeping.town"</span><span class="token punctuation">]</span><span class="token punctuation">,</span>
	<span class="token property">"members"</span><span class="token operator">:</span> <span class="token punctuation">[</span>
<span class="token punctuation">{</span>% for i in range(<span class="token number">0</span><span class="token punctuation">,</span> <span class="token number">5</span>) -%<span class="token punctuation">}</span><span class="token punctuation">{</span>% set j = options | random %<span class="token punctuation">}</span><span class="token punctuation">{</span>% set options = options | reject(<span class="token string">"eq"</span><span class="token punctuation">,</span> j) | join %<span class="token punctuation">}</span><span class="token punctuation">{</span># <span class="token number">8</span>&lt; snip<span class="token operator">:</span> secret #<span class="token punctuation">}</span><span class="token punctuation">{</span>%- endfor %<span class="token punctuation">}</span>		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":mt_crt_w_noise:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"unknown"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"Exa:???"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://exa.y2k.diy/junk/noise.png"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span>
	<span class="token punctuation">]</span>
<span class="token punctuation">}</span></span>
<span class="token punctuation">```</span></span>
[Order is randomized server-side when this page is recompiled.]{.small}

This data is encoded into our avatar, and automatically parsed out of it by the userscript when it first sees it.

At the top level, two values can be specified:

<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`accounts`</span>: An array of strings, specifying the accounts this system information should be used for. <span class="token italic"><span class="token punctuation">*</span><span class="token content">Only useful for specifying custom system data in userscript storage, does nothing when encoded into an avatar!!</span><span class="token punctuation">*</span></span>
<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`members`</span>: An array of members, described below.

Every object under the <span class="token code-snippet code keyword">`members`</span> array must contain exactly four values:

<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`emoji`</span>: An array or single value, describing the indicator to match on. Called "emoji" for legacy reasons, can also be a plaintext string signature.
<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`id`</span>: A string that will be shown after a slash in the modified username.
<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`name`</span>: A string that will replace the display name. If <span class="token code-snippet code keyword">`accounts`</span> is specified top-level and this is an array, then the name with the same index in this array as the account being matched will be used.
<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`avatar`</span>: Either the string "emoji" to use the emoji's own image (only reliable for custom emojis), or a URL to an avatar. By default, only URLs on the following domains are permitted:

  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`blob.jortage.com`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`pool.jortage.com`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`files.y2k.diy`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`cdn.pluralkit.me`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`cdn.plural.gg`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`scratchupload.xyz`</span>
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`scratchupload.org`</span>

<span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`font`</span>: Any of the following values:

  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`normal`</span>: Normal font rendering, no changes.
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`smallcaps`</span>: Small caps font variant. Browser and font specific.
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`small`</span>: 85% font scale.
  <span class="token list punctuation">*</span> <span class="token code-snippet code keyword">`monospace`</span>: System default monospace font.

This data can also be added into an array called <span class="token code-snippet code keyword">`custom-system-data`</span> in userscript storage. In Violentmonkey, you can edit this under the "Values" tab when editing the script. This allows configuring the tool for others accounts, or for having private data that isn't encoded into publicly-visible avatars.

![][custom-system-data]

<span class="token title important"><span class="token punctuation">##</span> Data Encoding Scheme (v1 / PlDon)</span>

The JSON payload is converted to UTF-8, prepended with "PlDon", and then written into the image starting at the final (bottom-right) pixel, scanning right-to-left, bottom-to-top. Horizontal lines are filled first.

Each byte is split like so:

[[RR]{.red}[GGG]{.green}[BBB]{.blue}]{.code}

So:

<span class="token list punctuation">*</span> The two most-significant bits go into the two least-significant bits of the red channel
<span class="token list punctuation">*</span> The three less-significant bits go into the three least-significant bits of the green channel
<span class="token list punctuation">*</span> The three least-significant bits go into the three least-significant bits of the blue channel

[Yes, it would be better to put two bits into green as human eyes are more sensitive to it. I designed this in a fugue late at night. PlDw2 does this.]{.small}

Here's the full-resolution version of our public avatar, with the data encoded into it:

![](https://blob.jortage.com/blob2/K4Tywj2q75RZZOkH/Fh1Wd9xrQKutp_pjgC0UzCZJhJ55VQk6R20UnObtS5O-CUQy1rwx7-e_jD1WSq/a_YFdnfQ.png)

There is a nearly-imperceptible few lines of noise at the bottom. Here's a 64x64 version (instead of 400x400) that has the same data, resized to be 4x larger:

![][demo]

The gradient at the bottom is noticeably distorted. And again, but on a uniform gray image:

![][demo2]

The first few bytes, from the bottom right of the image, with the contrast increased:

![][demo3]

If the <span class="token code-snippet code keyword">`PlDon`</span> marker string is detected, then the rest of the data up until the first NUL <span class="token code-snippet code keyword">`00`</span> byte will be decoded as UTF-8 and an attempt will be made to parse it as JSON in the above schema. If it looks valid, it will be loaded and used to decorate posts from the account that has the avatar.

<span class="token title important"><span class="token punctuation">##</span> Data Encoding Scheme (v2 / PlDw2)</span>

The JSON payload is parsed and converted into a binary stream. This stream is compressed with DEFLATE with the Zlib header, prepended with "PlDw2", and written into the image starting at the final (bottom-right) pixel, scanning right-to-left, bottom-to-top. Horizontal lines are filled first.

Each byte is split like so:

[[RRR]{.red}[GG]{.green}[BBB]{.blue}]{.code}

So:

<span class="token list punctuation">*</span> The three most-significant bits go into the three least-significant bits of the red channel
<span class="token list punctuation">*</span> The two less-significant bits go into the two least-significant bits of the green channel
<span class="token list punctuation">*</span> The three least-significant bits go into the three least-significant bits of the blue channel

The compressed binary stream is made up of "groups", which each define a single kind of value. A group is a series of UTF-8 encoded strings, each value delimited by U+001E RECORD SEPARATOR. A group is finished with U+001D GROUP SEPARATOR in place of the record separator. If a value is itself a list, the individual components of the list are delimited with U+001F UNIT SEPARATOR. The behavior of such list elements outside of the indicator group is presently undefined.

A string value within a group may start with U+0010 DATA LINK ESCAPE, in which case the next byte is to be interpreted as an unsigned index into an array of known prefixes. <span class="token italic"><span class="token punctuation">*</span><span class="token content">Due to this, you cannot decode the entire datastream as UTF-8. The byte following a DLE is not necessarily valid UTF-8!</span><span class="token punctuation">*</span></span>

The groups written, in order, are the IDs, names, indicators, avatars, and fonts. The lack of a group is indicated with U+0004 END OF TRANSMISSION — if this byte is not present after the fifth group, it indicates an extended format that is not defined at this time.

The IDs, names, indicators, and avatar groups are required. The fonts group may be absent, in which case all values are assumed to be <span class="token code-snippet code keyword">`normal`</span>.

[Using C0 control codes for their intended purpose in 2026.]{.small}

The avatars group uses the following prefix array:

<span class="token code"><span class="token punctuation">```</span>
<span class="token code-block">00. emoji
01. https://files.y2k.diy/
02. https://exa.y2k.diy/junk/noise.png
03. https://pool.jortage.com/
04. https://blob.jortage.com/
05. https://us.pool.jortage.com/
06. https://us.blob.jortage.com/
07. https://cn.pool.jortage.com/
08. https://cn.blob.jortage.com/
09. https://cdn.pluralkit.me/files/
0A. https://cdn.pluralkit.me/
0B. https://cdn.plural.gg/
0C. https://scratchupload.xyz/
0D. https://scratchupload.org/</span>
<span class="token punctuation">```</span></span>

The font group uses the following prefix array:

<span class="token code"><span class="token punctuation">```</span>
<span class="token code-block">00. normal
01. smallcaps
02. small
03. monospace</span>
<span class="token punctuation">```</span></span>

Data is strung together into typed groups in this way to improve compression, as it puts similar data next to eachother in the stream. DEFLATE has a relatively short context window, and this allows the format to take full advantage of it.

Given this sample system data in v1 / PlDon format:

<span class="token code"><span class="token punctuation">```</span><span class="token code-language">json</span>
<span class="token code-block language-json"><span class="token punctuation">{</span>
	<span class="token property">"members"</span><span class="token operator">:</span> <span class="token punctuation">[</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":zero:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"zero"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"0 Zero | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"normal"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":one:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"one"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"1 One | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://cdn.pluralkit.me/this-is-not-a-real-url/just-an-example.webp"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"monospace"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token string">":two:"</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"two"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"2 Two | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"emoji"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"smallcaps"</span>
		<span class="token punctuation">}</span><span class="token punctuation">,</span>
		<span class="token punctuation">{</span>
			<span class="token property">"emoji"</span><span class="token operator">:</span> <span class="token punctuation">[</span><span class="token string">":three:"</span><span class="token punctuation">,</span> <span class="token string">"~3"</span><span class="token punctuation">]</span><span class="token punctuation">,</span>
			<span class="token property">"id"</span><span class="token operator">:</span> <span class="token string">"three"</span><span class="token punctuation">,</span>
			<span class="token property">"name"</span><span class="token operator">:</span> <span class="token string">"3 Three | The Numerals"</span><span class="token punctuation">,</span>
			<span class="token property">"avatar"</span><span class="token operator">:</span> <span class="token string">"https://exa.y2k.diy/junk/noise.png"</span><span class="token punctuation">,</span>
			<span class="token property">"font"</span><span class="token operator">:</span> <span class="token string">"small"</span>
		<span class="token punctuation">}</span>
	<span class="token punctuation">]</span>
<span class="token punctuation">}</span></span>
<span class="token punctuation">```</span></span>

With hex numbers in square brackets indicating non-printable characters, and newlines as formatting, that would be encoded like so:

<span class="token code"><span class="token punctuation">```</span>
<span class="token code-block">zero[1E]one[1E]two[1E]three[1D]
0 Zero | The Numerals[1E]1 One | The Numerals[1E]2 Two | The Numerals[1E]3 Three | The Numerals[1D]
:zero:[1E]:one:[1E]:two:[1E]:three:[1F]~3[1D]
[10][00][1E][10][0A]this-is-not-a-real-url/just-an-example.webp[1E][10][00][1E][10][02][1D]
[10][00][1E][10][03][1E][10][01][1E][10][02][1D]
[04]</span>
<span class="token punctuation">```</span></span>

All groups must contain the same number of elements, and they are matched up into member data by index.

<span class="token title important"><span class="token punctuation">##</span> History</span>

This was originally a few hundred lines of LESS that compiled to a 15,000 line CSS file with hundreds of <span class="token code-snippet code keyword">`:has`</span> rules. The performance was <span class="token italic"><span class="token punctuation">_</span><span class="token content">abysmal</span><span class="token punctuation">_</span></span> and made using the Mastodon frontend miserable, but we found it worth it.

After trying to add support for somemany else's account to that disaster and it <span class="token italic"><span class="token punctuation">_</span><span class="token content">outright freezing our browser</span><span class="token punctuation">_</span></span>, I entered a fey mood and implemented the userscript in about 4 hours — an initial prototype that had feature parity with the CSS hack only took 30 minutes. It has none of the performance pitfalls or limitations of the original CSS hack.

See <span class="token url">[<span class="token content">the original dev thread</span>](<span class="token url">https://pub.mastodon.sleeping.town/@exa/115998367976937910</span>)</span> for more context and insight.

<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">before</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">after</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">custom-system-data</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">demo</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">demo2</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">demo3</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data


<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">tamper-incl</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data
<span class="token url-reference url"><span class="token punctuation">[</span><span class="token variable">tamper-incl-xhr</span><span class="token punctuation">]</span><span class="token punctuation">:</span> 8<span class="token punctuation">&lt;</span></span> snip: raw image data</code></pre>
	</div>
	<script>if (location.hash === '#view-source') document.getElementById('view-source').checked = true;</script>
</article>

		<footer>
			<div>Copyright © 2026 Exa Skye</div>
			<div><i>Not quite open source.</i> ♥</div>
		</footer>
	</body>
</html>



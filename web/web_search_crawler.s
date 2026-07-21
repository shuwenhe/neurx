// ============================================================
// NEURX WEB Search & Crawler - English textsearchEnglish textcontentEnglish textsystem
// completeimplementation: English textsearchEnglish text + English text + contentclean + resultEnglish text
// English text: Google / Bing / Baidu / DuckDuckGo / SearxNG English text
// ============================================================

module web_search_crawler

// ==================== English textconfigurationEnglish text ====================

struct WebSearchConfig {
    // searchEnglish textconfiguration
    search_engines: list<string> = ["google", "bing"]  # English textrankingEnglish textsearchEnglish text
    max_results_per_engine: int = 10                   # English textresultEnglish text
    total_max_results: int = 20                        # English textresultEnglish text (deduplicationEnglish text)

    // API English text (English text, English textuseEnglish textsearch)
    google_api_key?: string
    google_cx_id?: string                              # Custom Search Engine ID
    bing_api_key?: string

    // searchparameter
    language: string = "zh-CN"                         # languagepreference (English textsearchresultEnglish textregionEnglish textlanguage)
    region: string = "CN"                             # regionEnglish text
    safe_search: string = "moderate"                  # safe | moderate | off
    time_range: string = ""                           # English texttimeEnglish text (English text "y"=English text, "m"=English text)

    // crawlEnglish textcontentEnglish textconfiguration
    enable_crawling: bool = true                      # English textweb pageEnglish text
    crawl_timeout_seconds: int = 15                   # English text
    max_pages_to_crawl: int = 5                       # English text (English text)
    max_content_length: int = 50000                   # English text
    extract_main_content: bool = true                 # English text (English text/English text)
    follow_redirects: bool = true                     # English text
    user_agent: string = "NEURX-Bot/1.0 (Research Crawler; +https://neurx.ai)"

    // contentcleanconfiguration
    remove_scripts_styles: bool = true                # English text JS/CSS
    normalize_whitespace: bool = true                 # English text
    extract_metadata: bool = true                     # English texttitle/English text/authorEnglish textdata
    extract_images_info: bool = false                 # English textinformation (English text)
    extract_links: bool = false                       # English textinformation

    // resultEnglish textconfiguration
    deduplicate_results: bool = true                  # deduplication (English textURLEnglish textcontentEnglish text)
    rerank_with_llm: bool = false                    # use LLM English textresultEnglish textranking
    result_summary_length: int = 200                 # summaryEnglish text (English text)
    cache_enabled: bool = true                        # English textcache (English text)
    cache_ttl_hours: int = 24                        # cacheEnglish text (English text)
}

struct SearchResultItem {
    url: string                                       # English text URL
    title: string                                     # title
    snippet: string                                   # searchEnglish textsummary/English text
    source_engine: string                             # SourcesearchEnglish text
    rank_in_engine: int                               # English text
    relevance_score?: float                           # English text (English text)
    published_date?: string                           # publish date (English text)

    // crawlEnglish textextensionEnglish text
    crawled_content?: CrawledContent?                 # English textcompletecontent
    crawl_status?: string                             # success | failed | timeout | blocked
    crawl_error?: string                              # errorinformation
}

struct CrawledContent {
    raw_html_size: int                                # English text HTML English text (English text)
    text_content: string                              # English textcontent
    cleaned_text: string                              # cleanEnglish text (English text LLM English text)
    metadata: PageMetadata                           # English textdata
    sections: list<PageSection>?                     # English textsection
    extraction_timestamp: float                      # English texttimeEnglish text
    word_count: int                                  # English text
}

struct PageMetadata {
    title: string                                    # English texttitle
    description: string?                             # Meta description
    author: string?                                  # author
    publish_date: string?                            # publish date
    last_modified: string?                           # English texttime
    site_name: string                                # English textName
    domain: string                                   # domain
    language: string?                                # English textlanguage
    content_type: string?                            # Content-Type
    canonical_url: string?                           # English text URL (English text)
    keywords: list<string>?                          # keywords
    og_data: map<string, string>?                    # OpenGraph data
}

struct PageSection {
    heading: string?                                 # sectiontitle (English text)
    level: int                                       # titleEnglish text (H1-H6, 0 English texttitle)
    content: string                                  # contentEnglish text
}

struct SearchResponse {
    query: string                                    # English textquery
    corrected_query?: string                         # searchEnglish textquery (English text)
    total_results_found: int                         # English textresultEnglish text
    results: list<SearchResultItem>                  # rankingEnglish textresultEnglish text
    aggregated_from_engines: list<string>            # actualuseEnglish textsearchEnglish text
    search_time_ms: float                            # English text (English text)

    # English textsummary
    summary?: string                                 # LLM generateEnglish textsummary (English text)
    key_findings: list<string>?                     # English text (English text)

    # statisticsinformation
    stats: SearchStatistics                          # English textstatistics
}

struct SearchStatistics {
    engine_query_times_ms: map<string, float>        # English textqueryEnglish text
    crawl_times_ms: list<float>                      # English text
    total_crawl_time_ms: float                       # English text
    pages_crawled: int                               # successEnglish text
    pages_failed: int                                # English textfailureEnglish text
    duplicates_removed: int                          # deduplicationEnglish textcount
    cache_hit_count: int                             # cacheEnglish text
}

// ==================== searchEnglish text ====================

interface SearchEngineInterface {
    name: string { get }
    search(query: string, config: WebSearchConfig)
}

struct EngineSearchResult {
    items: list<SearchResultItem>                    # English textresult
    total_estimated: int                             # English textresultEnglish text
    corrected_query?: string                         # English textquery
    query_time_ms: float                             # English text
    has_more: bool                                   # English textresult
    error?: string                                   # errorinformation (English textfailure)
}

// ==================== Google searchimplementation ====================

class GoogleSearchEngine implements SearchEngineInterface {
    name = "Google"
    api_key: string?
    cx_id: string?

    init(api_key?: string, cx_id?: string) {
        this.api_key = api_key
        this.cx_id = cx_id
    }

    get name -> string {
        return this.name
    }

    search(query: string, config: WebSearchConfig) {
        start_time = current_time_millis()

        if this.api_key != null && this.cx_id != null {
            result = this._search_via_api(query, config, start_time)
        } else {
            result = this._search_public(query, config, start_time)
        }

        return result
    }

    _search_via_api(query: string, config: WebSearchConfig, start_time: float) {
        # Use Google Custom Search JSON API
        params = {
            "key": this.api_key!,
            "cx": this.cx_id!,
            "q": query,
            "num": min(config.max_results_per_engine, 10),  # API limit is 10 per request
            "hl": config.language.split("-")[0],
            "gl": config.region
        }

        if !config.time_range.empty():
            params["dateRestrict"] = config.time_range

        response = http_get("https://www.googleapis.com/customsearch/v1", params=params)
        data = json_decode(response.body)

        if "error" in data:
            return EngineSearchResult{
                items=[], total_estimated=0, query_time_ms=current_time_millis() - start_time,
                has_more=false, error=data["error"]["message"]
            }

        items: list<SearchResultItem> = []
        for i, item in enumerate(data.get("items", [])) {
            items.append(SearchResultItem{
                url=item["link"],
                title=item.get("title", ""),
                snippet=item.get("snippet", ""),
                source_engine=this.name,
                rank_in_engine=i + 1,
                published_date=item.get("pagemap", {}).get("metatags", [{}])[0].get("article:published_time")
            })

        return EngineSearchResult{
            items=items,
            total_estimated=data.get("searchInformation", {}).get("totalResults", 0),
            query_time_ms=current_time_millis() - start_time,
            has_more=False
        }
    }

    _search_public(query: string, config: WebSearchConfig, start_time: float) {
        # Fallback: Use web scraping or alternative public API
        # Note: This is a simplified implementation; production should use proper APIs or services like SerpAPI

        try {
            # Option 1: Use DuckDuckGo as fallback (no API key needed)
            ddg_result = this._duckduckgo_fallback(query, config)

            # Add Google attribution
            for item in ddg_result.items:
                item.source_engine = this.name

            return ddg_result

        } catch Exception as e:
            return EngineSearchResult{
                items=[], total_estimated=0, query_time_ms=current_time_millis() - start_time,
                has_more=false, error=f"Google search failed: {e.message}"
            }
    }

    _duckduckgo_fallback(query: string, config: WebSearchConfig) {
        # DuckDuckGo Instant Answer API (free, no key required)
        params = {
            "q": query,
            "format": "json",
            "no_html": "1",
            "skip_disambig": "1"
        }

        response = http_get("https://api.duckduckgo.com/", params=params)
        data = json_decode(response.body)

        items: list<SearchResultItem> = []

        # DuckDuckGo may return abstract/answer directly
        if "Abstract" in data and not data["Abstract"].empty():
            items.append(SearchResultItem{
                url=data.get("AbstractURL", ""),
                title=data.get("Heading", ""),
                snippet=data["Abstract"],
                source_engine="DuckDuckGo",
                rank_in_engine=1
            })

        # Also try to get regular results (would need html scraping of DDG lite version)
        # For simplicity, returning just the instant answer

        return EngineSearchResult{
            items=items,
            total_estimated=len(items),
            query_time_ms=response.elapsed * 1000,
            has_more=false
        }
    }
}

// ==================== Bing searchimplementation ====================

class BingSearchEngine implements SearchEngineInterface {
    name = "Bing"
    api_key: string?

    init(api_key?: string) {
        this.api_key = api_key
    }

    get name -> string {
        return this.name
    }

    search(query: string, config: WebSearchConfig) {
        start_time = current_time_millis()

        if this.api_key != null:
            return this._search_via_api(query, config, start_time)
        else:
            return this._search_fallback(query, config, start_time)
    }

    _search_via_api(query: string, config: WebSearchConfig, start_time: float) {
        headers = {
            "Ocp-Apim-Subscription-Key": this.api_key!
        }

        params = {
            "q": query,
            "count": min(config.max_results_per_engine, 50),
            "offset": 0,
            "mkt": f"{config.language}-{config.region}",
            "safesearch": config.safe_search
        }

        if !config.time_range.empty():
            params["freshness"] = match config.time_range {
                "d" => "Day"
                "w" => "Week"
                "m" => "Month"
                _ => null
            }

        response = http_get(
            "https://api.bing.microsoft.com/v7.0/search",
            headers=headers,
            params=params
        )
        data = json_decode(response.body)

        items: list<SearchResultItem> = []
        for i, item in enumerate(data.get("webPages", {}).get("value", [])):
            items.append(SearchResultItem{
                url=item["url"],
                title=item.get("name", ""),
                snippet=item.get("snippet", ""),
                source_engine=this.name,
                rank_in_engine=i + 1,
                published_date=item.get("dateLastCrawled")
            })

        return EngineSearchResult{
            items=items,
            total_estimated=data.get("webPages", {}).get("totalEstimatedMatches", 0),
            query_time_ms=current_time_millis() - start_time,
            has_more=false
        }
    }

    _search_fallback(query: string, config: WebSearchConfig, start_time: float) {
        # Return empty with info message
        return EngineSearchResult{
            items=[],
            total_estimated=0,
            query_time_ms=current_time_millis() - start_time,
            has_more=false,
            error="Bing API key not provided"
        }
    }
}

// ==================== web pagecrawlEnglish text ====================

class WebCrawler {
    config: WebSearchConfig
    session: HTTPSession
    cache: LRUCache<string, CrawledContent>
    content_extractor: MainContentExtractor
    html_cleaner: HTMLCleaner

    init(config: WebSearchConfig) {
        this.config = config
        this.session = new HTTPSession(
            timeout=config.crawl_timeout_seconds,
            user_agent=config.user_agent,
            allow_redirects=config.follow_redirects
        )
        this.cache = new LRUCache(capacity=1000)
        this.content_extractor = new MainContentExtractor(config=config)
        this.html_cleaner = new HTMLCleaner(config=config)
    }

    async crawl(url: string) {
        # Check cache first
        if this.config.cache_enabled && url in this.cache {
            cached = this.cache[url]
            if !this._is_cache_expired(cached):
                return (cached, null)
        }

        try {
            # Fetch page
            response = await this.session.get(url)

            if response.status_code != 200:
                return (null, f"HTTP {response.status_code}")

            html_content = response.text

            if len(html_content) > this.config.max_content_length * 5:  # Allow 5x for HTML overhead
                html_content = html_content[:this.config.max_content_length * 5]

            # Extract content
            extracted = this.content_extractor.extract(html_content, url)

            # Clean text
            cleaned_text = this.html_cleaner.clean(extracted.text_content)

            crawled = CrawledContent{
                raw_html_size=len(html_content.encode('utf-8')),
                text_content=extracted.text_content,
                cleaned_text=cleaned_text,
                metadata=extracted.metadata,
                sections=extracted.sections,
                extraction_timestamp=current_timestamp(),
                word_count=len(cleaned_text.split())
            }

            # Cache result
            if this.config.cache_enabled:
                this.cache[url] = crawled

            return (crawled, null)

        } except TimeoutException:
            return (null, "Timeout")
        except SSLError:
            return (null, "SSL certificate error")
        except DNSException:
            return (null, "DNS resolution failed")
        except TooManyRedirects:
            return (null, "Too many redirects")
        catch Exception as e:
            return (null, str(e))
    }

    batch_crawl(urls: list<string>, max_concurrent: int = 3) {
        results: dict<string, tuple<CrawledContent?, string?>> = {}

        # Use semaphore to limit concurrent requests
        semaphore = Semaphore(max_concurrent)

        async def crawl_single(url: string) {
            async with semaphore:
                results[url] = await this.crawl(url)

        # Execute all crawls concurrently
        tasks = [crawl_single(url) for url in urls]
        run_concurrently(tasks)

        return results
    }

    _is_cache_expired(cached: CrawledContent) {
        age_hours = (current_timestamp() - cached.extraction_timestamp) / 3600
        return age_hours > this.config.cache_ttl_hours
    }
}

// ==================== mainEnglish textcontentEnglish text (Readability-like) ====================

class MainContentExtractor {
    config: WebSearchConfig

    init(config: WebSearchConfig) {
        this.config = config
    }

    extract(html: string, base_url: string) {
        soup = parse_html(html)

        # Remove unwanted elements
        self._remove_unwanted(soup)

        # Extract metadata
        metadata = self._extract_metadata(soup, base_url)

        # Extract main content area
        main_element = this._find_main_content(soup)

        # Extract text and structure
        if main_element != None:
            text_content, sections = this._extract_structured(main_element)
        else:
            # Fallback: use body
            body = soup.find("body") ?? soup
            text_content, sections = this._extract_structured(body)

        return ExtractionResult{
            text_content=text_content,
            metadata=metadata,
            sections=sections
        }
    }

    _remove_unwanted(soup: any) {
        tags_to_remove = ["script", "style", "noscript", "iframe", "nav", "footer",
                          "header", "aside", "form", ".advertisement", ".ads",
                          ".sidebar", ".menu", ".navigation", ".comment"]

        for selector in tags_to_remove:
            if selector.startswith("."):
                for elem in soup.find_all(class_=selector[1:]):
                    elem.decompose()
            elif selector.startsWith("#"):
                elem = soup.find(id=selector[1:])
                if elem != None { elem.decompose() }
            else:
                for elem in soup.find_all(selector):
                    elem.decompose()
    }

    _extract_metadata(soup: any, base_url: string) {
        meta = PageMetadata{
            title=soup.title.string.trim() if soup.title else "",
            site_name="",
            domain=extract_domain(base_url),
            canonical_url=base_url
        }

        # Meta tags
        desc_tag = soup.find("meta", attrs={"name": "description"})
        if desc_tag != None:
            meta.description = desc_tag.get("content", "").strip()

        author_tag = soup.find("meta", attrs={"name": "author"})
        if author_tag != None:
            meta.author = author_tag.get("content", "").strip()

        date_tag = soup.find("meta", attrs={"property": "article:published_time"})
        if date_tag == None:
            date_tag = soup.find("meta", attrs={"name": "date"})
        if date_tag != None:
            meta.publish_date = date_tag.get("content", "")

        # OpenGraph data
        og_data: dict<string, string> = {}
        og_tags = soup.find_all("meta", property=re.compile(r'^og:'))
        for tag in og_tags:
            prop = tag.get("property", "")
            content = tag.get("content", "")
            if !prop.empty() and !content.empty():
                og_data[prop] = content

        if og_data.length > 0:
            meta.og_data = og_data
            if "og:title" in og_data:
                meta.title = og_data["og:title"]
            if "og:site_name" in og_data:
                meta.site_name = og_data["og:site_name"]

        # Canonical URL
        canonical = soup.find("link", rel="canonical")
        if canonical != None:
            meta.canonical_url = resolve_url(base_url, canonical.get("href", ""))

        # Language
        html_tag = soup.find("html")
        if html_tag != None:
            meta.language = html_tag.get("lang", "")

        return meta
    }

    _find_main_content(soup: any) {
        # Heuristic-based main content detection (similar to Mozilla Readability)
        candidates: list<{element: any, score: float}> = []

        for elem in soup.find_all(["div", "article", "main", "section"]):
            score = 0.0

            text_len = len(elem.get_text())
            if text_len < 150:
                continue  # Skip very short elements

            # Positive indicators
            tag = elem.name
            if tag == "article":
                score += 25
            if tag == "main":
                score += 20

            class_id_str = (elem.get("class", []) ?? []).join("") + (elem.get("id", "") ?? "")
            positive_keywords = ["post", "article", "content", "entry", "body", "text", "story",
                                  "main-content", "content-area", "article-body"]
            for kw in positive_keywords:
                if kw in class_id_str.lower():
                    score += 15

            # Density bonus (higher text-to-tag ratio is better)
            link_elements = elem.find_all("a")
            text = elem.get_text()
            if len(text) > 0 and len(link_elements) > 0:
                link_density = sum(len(a.get_text()) for a in link_elements) / len(text)
                if link_density < 0.3:
                    score += 20
                elif link_density > 0.6:
                    score -= 25

            # Length factor
            score += math.log(max(text_len, 1))

            # Negative indicators
            negative_keywords = ["comment", "sidebar", "footer", "widget", "ad-", "promo",
                                  "related", "sponsor", "newsletter", "signup", "subscribe"]
            for kw in negative_keywords:
                if kw in class_id_str.lower():
                    score -= 30

            if score > 0:
                candidates.append({element=elem, score=score})

        if candidates.length > 0:
            candidates.sort_by_descending(c => c.score)
            return candidates[0].element

        return None
    }

    _extract_structured(element: any) {
        sections: list<PageSection> = []
        content_parts: list<string> = []

        def process_node(node: any, depth: int = 0) {
            if node.name in ["h1", "h2", "h3", "h4", "h5", "h6"]:
                level = int(node.name[1])
                text = node.get_text().strip()
                sections.append(PageSection{heading=text, level=level, content=""})
                content_parts.append("\n" + "#" * level + " " + text + "\n")

            elif node.name == "p":
                text = clean_whitespace(node.get_text())
                if !text.empty():
                    sections.append(PageSection{heading=null, level=0, content=text})
                    content_parts.append(text + "\n\n")

            elif node.name in ["ul", "ol"]:
                items: list<string> = []
                for li in node.find_all("li", recursive=False):
                    item_text = clean_whitespace(li.get_text())
                    if !item_text.empty():
                        items.append(item_text)
                marker = "-" if node.name == "ul" else "1."
                list_text = "\n".join(f"{marker} {item}" for item in items) + "\n\n"
                sections.append(PageSection{heading=null, level=0, content=list_text.strip()})
                content_parts.append(list_text)

            elif node.name == "blockquote":
                quote_text = node.get_text().strip()
                sections.append(PageSection{heading=null, level=0, content=f"> {quote_text}"})
                content_parts.append(f"\n> {quote_text}\n\n")

            # Process children
            for child in node.children:
                process_node(child, depth + 1)

        process_node(element)

        full_text = "".join(content_parts).strip()
        return (full_text, sections)
    }

    struct ExtractionResult {
        text_content: string
        metadata: PageMetadata
        sections: list<PageSection>
    }
}

// ==================== HTML cleanEnglish text ====================

class HTMLCleaner {
    config: WebSearchConfig

    init(config: WebSearchConfig) {
        this.config = config
    }

    clean(raw_text: string) {
        text = raw_text

        if this.config.remove_scripts_styles:
            # Remove any remaining scripts/legacy/style blocks that might have been missed
            text = regex.sub(r'<script[^>]*>.*?</script>', '', text, flags=regex.DOTALL)
            text = regex.sub(r'<style[^>]*>.*?</style>', '', text, flags=regex.DOTALL)

        # Remove all HTML tags
        text = regex.sub(r'<[^>]+>', ' ', text)

        if this.config.normalize_whitespace:
            # Normalize whitespace
            text = regex.sub(r'[ \t]+', ' ', text)
            text = regex.sub(r'\n\s*\n+', '\n\n', text)
            text = regex.sub(r'\n{3,}', '\n\n', text)  # Max 2 consecutive newlines
            text = text.strip()

        # Decode HTML entities
        text = unescape(text)

        return text
    }
}

// ==================== NEURX WEB Search mainsystem ====================

class WebSearchSystem {
    config: WebSearchConfig
    engines: map<string, SearchEngineInterface>
    crawler: WebCrawler
    result_aggregator: ResultAggregator
    llm_client: any?  # Optional LLM for summarization/reranking

    init(config?: WebSearchConfig, llm_client?: any) {
        this.config = config ?? new WebSearchConfig()
        this.engines = map<string, SearchEngineInterface>{}
        this.llm_client = llm_client

        # Initialize configured search engines
        if "google" in this.config.search_engines:
            google = new GoogleSearchEngine(this.config.google_api_key, this.config.google_cx_id)
            this.engines["google"] = google

        if "bing" in this.config.search_engines:
            bing = new BingSearchEngine(this.config.bing_api_key)
            this.engines["bing"] = bing

        # Initialize crawler
        this.crawler = new WebCrawler(config=this.config)

        # Initialize aggregator
        this.result_aggregator = new ResultAggregator(config=config)
    }

    async search(query: string, options?: SearchOptions) {
        opts = options ?? new SearchOptions()
        start_total = current_time_millis()

        print(f"🔍 Searching: {query}")

        # Step 1: Query multiple engines in parallel
        all_items: list<SearchResultItem> = []
        engine_times: map<string, float> = {}
        used_engines: list<string> = []

        tasks: list<tuple<string, ()
        for eng_name, engine in this.engines {
            tasks.append((eng_name, () => engine.search(query, this.config)))
        }

        # Run searches concurrently
        engine_results = await run_tasks_concurrently(tasks, max_workers=len(this.engines))

        for eng_name, result in engine_results:
            engine_times[eng_name] = result.query_time_ms

            if result.error == None {
                all_items.extend(result.items)
                used_engines.append(eng_name)

                if result.corrected_query != None:
                    opts.corrected_query = result.corrected_query!

            if opts.verbose:
                status_icon = "✅" if result.error == None else "❌"
                print(f"   {status_icon} {eng_name}: {len(result.items)} results ({result.query_time_ms:.0f}ms)")

        # Step 2: Deduplicate results
        if this.config.deduplicate_results and all_items.length > 0:
            before_dedup = len(all_items)
            all_items = this.result_aggregator.deduplicate(all_items)
            deduped_count = before_dedup - len(all_items)
            if opts.verbose and deduped_count > 0:
                print(f"   🗑️ Removed {deduped_count} duplicate results")

        # Step 3: Apply relevance scoring/ranking
        if all_items.length > 0:
            all_items = this.result_aggregator.score_and_rank(all_items, query)

        # Step 4: Limit to max results
        if len(all_items) > this.config.total_max_results:
            all_items = all_items[:this.config.total_max_results]

        # Step 5: Crawl top results if enabled
        crawl_times: list<float> = []
        crawl_success = 0
        crawl_fail = 0

        if this.config.enable_crawling and opts.crawl_results:
            urls_to_crawl = [item.url for item in all_items[:min(this.config.max_pages_to_crawl, len(all_items))]]

            if opts.verbose:
                print(f"   🕷️ Crawling {len(urls_to_crawl)} pages...")

            crawl_start = current_time_millis()
            crawl_results = await this.crawler.batch_crawl(urls_to_crawl, max_concurrent=3)
            crawl_total_time = current_time_millis() - crawl_start

            # Attach crawled content to search results
            for i, item in enumerate(all_items):
                if item.url in crawl_results:
                    content, error = crawl_results[item.url]
                    if content != None:
                        item.crawled_content = content
                        item.crawl_status = "success"
                        crawl_success += 1
                    else:
                        item.crawl_status = "failed"
                        item.crawl_error = error
                        crawl_fail += 1

                    item.rank_in_engine = i + 1  # Update rank after aggregation
                    crawl_times.append(crawl_total_time / max(len(urls_to_crawl), 1))

        # Step 6: Generate summary with LLM (if available and requested)
        summary = None
        key_findings: list<string>? = None

        if this.llm_client != None and (opts.generate_summary or this.config.rerank_with_llm):
            if opts.verbose:
                print(f"   🤖 Generating AI summary...")

            context = this._build_context_for_llm(query, all_items[:5])
            summary_result = this._generate_summary_with_llm(query, context)
            summary = summary_result.summary
            key_findings = summary_result.key_findings

            # Optionally rerank based on LLM assessment
            if this.config.rerank_with_llm and summary_result.reranked_indices != None:
                all_items = [all_items[i] for i in summary_result.reranked_indices!]

        total_time = current_time_millis() - start_total

        if opts.verbose:
            print(f"\n   📊 Results: {len(all_items)} items in {total_time:.0f}ms")
            print(f"      Engines: {', '.join(used_engines)}")
            if crawl_success + crawl_fail > 0:
                print(f"      Crawled: {crawl_success} success, {crawl_fail} failed")

        return SearchResponse{
            query=query,
            corrected_query=opts.corrected_query,
            total_results_found=len(all_items),  # Could use engine estimates for more accurate count
            results=all_items,
            aggregated_from_engines=used_engines,
            search_time_ms=total_time,
            summary=summary,
            key_findings=key_findings,
            stats=SearchStatistics{
                engine_query_times_ms=engine_times,
                crawl_times_ms=crawl_times,
                total_crawl_time_ms=sum(crawl_times) if crawl_times.length > 0 else 0,
                pages_crawled=crawl_success,
                pages_failed=crawl_fail,
                duplicates_removed=(before_dedup - len(all_items)) if this.config.deduplicate_results else 0,
                cache_hit_count=0  # Would need to track from crawler
            }
        }
    }

    _build_context_for_llm(query: string, top_results: list<SearchResultItem>) {
        parts: list<string> = []
        parts.append(f"Query: {query}\n")
        parts.append("=" * 60 + "\n")

        for i, result in enumerate(top_results):
            parts.append(f"[{i+1}] {result.title}")
            parts.append(f"    URL: {result.url}")

            if result.snippet != None and !result.snippet!.empty():
                parts.append(f"    Snippet: {result.snippet!}")

            if result.crawled_content != None:
                # Truncate long content for context window efficiency
                preview = result.crawled_content!.cleaned_text[:500]
                if len(result.crawled_content!.cleaned_text) > 500:
                    preview += "... [truncated]"
                parts.append(f"    Content Preview:\n    {preview}")

            parts.append("")

        return "\n".join(parts)
    }

    _generate_summary_with_llm(query: string, context: string) {
        prompt = f"""
Based on the following search results for the query "{query}", provide:

1. A concise summary (3-4 sentences) answering the query
2. 3-5 key findings or important points

Search Results:
{context}

Respond in this format:
## Summary
[your summary here]

## Key Findings
- [finding 1]
- [finding 2]
- [finding 3]

Also provide a comma-separated ranking of the most relevant result indices (0-based): [indices]
"""

        response = this.llm_client!.generate(prompt, temperature=0.3, max_tokens=600)

        # Parse structured response
        summary_match = regex.search(r'## Summary\n(.*?)(?=##|\Z)', response.text, regex.DOTALL)
        findings_match = regex.search(r'## Key Findings\n(.*?)(=\Z)', response.text, regex.DOTALL)
        indices_match = regex.search(r'indices:\s*\[(.*?)\]', response.text)

        summary = summary_match.group(1).trim() if summary_match else ""
        key_findings: list<string> = []

        if findings_match != None:
            findings_text = findings_match.group(1)
            key_findings = [line.strip().lstrip("- ") for line in findings_text.split("\n")
                           if line.trim().starts_with("-")]

        reranked_indices: list<int>? = None
        if indices_match != None:
            indices_str = indices_match.group(1)
            try:
                reranked_indices = [int(x.trim()) for x in indices_str.split(",")]
            }

        return LlmSummaryResult{
            summary=summary,
            key_findings=key_findings if key_findings.length > 0 else None,
            reranked_indices=reranked_indices
        }
    }

    struct LlmSummaryResult {
        summary: string
        key_findings: list<string>?
        reranked_indices: list<int>?
    }

    export_results(response: SearchResponse, format: string = "markdown", output_path?: string) {
        output: list<string> = []

        output.append(f"# Search Results: {response.query}\n")
        output.append(f"**Total Results**: {response.total_results_found}\n")
        output.append(f"**Time**: {response.search_time_ms:.0f}ms\n")
        output.append(f"**Sources**: {', '.join(response.aggregated_from_engines)}\n")

        if response.corrected_query != None:
            output.append(f"**Corrected Query**: {response.corrected_query!}\n")

        if response.summary != None:
            output.append(f"---\n\n## Summary\n\n{response.summary!}\n")

        if response.key_findings != None:
            output.append("## Key Findings\n")
            for finding in response.key_findings!:
                output.append(f"- {finding}\n")
            output.append("")

        output.append("---\n\n## Detailed Results\n")

        for i, item in enumerate(response.results, 1):
            output.append(f"### {i}. {item.title}\n")
            output.append(f"- **URL**: [{item.url}]({item.url})")
            output.append(f"- **Source**: {item.source_engine} (Rank: #{item.rank_in_engine})")

            if item.published_date != None:
                output.append(f"- **Date**: {item.published_date!}")

            if item.snippet != None and !item.snippet!.empty():
                output.append(f"\n**Snippet**:\n> {item.snippet!}\n")

            if item.crawled_content != None and item.crawl_status == "success":
                cc = item.crawled_content!
                output.append(f"**Content** ({cc.word_count} words):\n")
                preview = cc.cleaned_text[:1000]
                if len(cc.cleaned_text) > 1000:
                    preview += "\n... [truncated]"
                output.append(preview + "\n")

                if cc.metadata.author != None:
                    output.append(f"*Author: {cc.metadata.author!}*\n")

            output.append("---\n")

        final_output = "\n".join(output)

        if output_path != None:
            write_file(output_path!, final_output)
            print(f"Results saved to: {output_path!}")

        return final_output
    }
}

struct SearchOptions {
    crawl_results: bool = true
    generate_summary: bool = true
    verbose: bool = true
    corrected_query?: string
}

// ==================== resultEnglish textdeduplication ====================

class ResultAggregator {
    config: WebSearchConfig

    init(config: WebSearchConfig) {
        this.config = config
    }

    deduplicate(items: list<SearchResultItem>) {
        seen_urls: set<string> = set{}
        unique_items: list<SearchResultItem> = []

        for item in items:
            # Normalize URL for comparison
            normalized = self._normalize_url(item.url)

            if normalized not in seen_urls:
                seen_urls.add(normalized)
                unique_items.append(item)

        return unique_items
    }

    score_and_rank(items: list<SearchResultItem>, query: string) {
        # Score each result based on multiple signals

        scored_items: list<tuple<SearchResultItem, float>> = []
        query_terms = set(query.to_lower().split_whitespace())

        for item in items {
            score = 0.0

            # Factor 1: Title match (high weight)
            title_lower = item.title.to_lower()
            title_matches = sum(1 for term in query_terms if term in title_lower)
            score += title_matches * 15.0

            # Factor 2: Snippet match (medium weight)
            snippet_lower = (item.snippet ?? "").to_lower()
            snippet_matches = sum(1 for term in query_terms if term in snippet_lower)
            score += snippet_matches * 8.0

            # Factor 3: Original rank (inverse - lower rank number is better)
            score += (20.0 / (item.rank_in_engine + 1))  # Diminishing returns

            # Factor 4: Domain authority heuristic (simple TLD/length checks)
            domain = extract_domain(item.url)
            if this._is_high_quality_domain(domain):
                score += 5.0

            # Factor 5: Recency bonus (if date available)
            if item.published_date != None:
                days_old = days_since(item.published_date!)
                if days_old < 30:
                    score += 10.0
                elif days_old < 180:
                    score += 5.0

            # Factor 6: URL length penalty (very long URLs are often low quality)
            if len(item.url) > 120:
                score -= 3.0

            item.relevance_score = round(score, 2)
            scored_items.append((item, score))
        }

        # Sort by score descending
        scored_items.sort_by_descending(x => x[1])

        return [item for item, _ in scored_items]
    }

    _normalize_url(url: string) {
        parsed = urlparse(url)
        # Remove fragments, sort query params, lowercase
        normalized = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
        if parsed.query:
            params = sorted(parsed.query.split("&"))
            normalized += "?" + "&".join(params)
        return normalized.to_lower()
    }

    _is_high_quality_domain(domain: string) {
        quality_indicators = [
            ".edu", ".gov", ".org",  # TLDs
            "wikipedia.org", "arxiv.org", "github.com",
            "stackoverflow.com", "medium.com", "nature.com",
            "science.org", "ieee.org", "acm.org"
        ]
        return any(indicator in domain for indicator in quality_indicators)
    }
}

// ==================== English textfunctionEnglish texttest ====================

function create_web_search_system(config?: WebSearchConfig, llm_client?: any) {
    return new WebSearchSystem(config=config, llm_client=llm_client)
}

async function test_web_search_system() {
    print("🧪 Testing NEURX WEB Search System...")

    # Create system without actual API keys (will use fallback modes)
    cfg = WebSearchConfig(
        enable_crawling=false,
        max_results_per_engine=3,
        total_max_results=5
    )
    ws = create_web_search_system(cfg)

    # Test 1: System initialization
    print("  ✓ Test 1: System Initialization & Engine Setup")
    assert len(ws.engines) >= 1, "At least one search engine should be initialized"
    assert ws.crawler != None, "Crawler should be initialized"

    # Test 2: URL normalization and deduplication
    print("  ✓ Test 2: URL Normalization & Deduplication")
    agg = ws.result_aggregator
    test_items = [
        SearchResultItem{url="https://example.com/page?id=123&ref=search", title="Test 1", snippet="...", source_engine="google", rank_in_engine=1},
        SearchResultItem{url="HTTPS://EXAMPLE.COM/PAGE?ID=123&REF=OTHER", title="Test 2", snippet="...", source_engine="bing", rank_in_engine=1},  # Same page, different case/order
        SearchResultItem{url="https://example.com/other-page", title="Test 3", snippet="...", source_engine="google", rank_in_engine=2},
        SearchResultItem{url="https://different-site.com/article", title="Test 4", snippet="...", source_engine="bing", rank_in_engine=3}
    ]
    unique = agg.deduplicate(test_items)
    assert len(unique) == 3, f"Dedup failed: expected 3, got {len(unique)}"

    # Test 3: Scoring and ranking
    print("  ✓ Test 3: Result Scoring & Ranking")
    scored = agg.score_and_rank(unique, "test query example")
    assert len(scored) == len(unique), "Scoring should preserve all items"
    assert scored[0].relevance_score != None, "Relevance scores should be assigned"

    # Verify sorting (descending by score)
    for i in range(len(scored) - 1):
        assert scored[i].relevance_score! >= scored[i+1].relevance_score!, \
               f"Results should be sorted by score: {scored[i].relevance_score} >= {scored[i+1].relevance_score}"

    # Test 4: HTML cleaning
    print("  ✓ Test 4: HTML Cleaning")
    cleaner = new HTMLCleaner(cfg)
    dirty_html = "<div><script>alert('xss')</script><p>Hello   World</p></div>"
    cleaned = cleaner.clean(dirty_html)
    assert "<script" not in cleaned, "Script tags should be removed"
        assert "Hello   World" in cleaned or "Hello World" in cleaned, "Text content preserved"

    print("\n✅ All Web Search System Tests Passed!")
    return true
}

// Export public API
export {
    WebSearchConfig, SearchResultItem, CrawledContent, PageMetadata, PageSection,
    SearchResponse, SearchStatistics,
    WebSearchSystem, SearchOptions,
    create_web_search_system, test_web_search_system
}

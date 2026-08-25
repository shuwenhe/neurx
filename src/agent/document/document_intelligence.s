module document_parser

struct document_parser_config {
    enabled_formats: list<string> = ["pdf", "html", "markdown", "docx", "pptx", "xlsx", "txt", "csv"]
    pdf_extract_images: bool = true
    pdf_ocr_enabled: bool = false
    pdf_ocr_language: string = "chi_sim+eng"
    pdf_preserve_layout: bool = true
    pdf_extract_tables: bool = true
    html_clean_html: bool = true
    html_extract_main_content: bool = true
    html_remove_elements: list<string> = ["script", "style", "nav", "footer", "header", "aside"]
    html_keep_links: bool = true
    md_extract_code_blocks: bool = true
    md_extract_tables: bool = true
    md_handle_front_matter: bool = true
    md_parse_math: bool = true
    office_extract_embedded: bool = true
    office_resolve_styles: bool = true
    table_detection_method: string = "auto"
    table_header_detection: bool = true
    table_merge_cell_support: bool = true
    output_format: string = "markdown"
    max_file_size_mb: int = 100
    chunk_size: int = 1000
    chunk_overlap: int = 200
    enable_metadata_extraction: bool = true
    enable_section_detection: bool = true
    enable_page_numbering: bool = true
}

struct parsed_document {
    content: string
    metadata: document_metadata
    sections: list<document_section>
    tables: list<extracted_table>
    images: list<extracted_image>
    links: list<extracted_link>
    code_blocks: list<code_block>
    statistics: document_statistics
    raw_structure: any
}

struct document_metadata {
    filename: string
    file_path: string
    file_format: string
    file_size_bytes: int
    mime_type: string
    title: string
    author: string
    created_date: string
    modified_date: string
    page_count: int
    word_count: int
    language: string
    encoding: string
}

struct document_section {
    id: string
    title: string
    level: int
    content: string
    start_position: int
    end_position: int
    page_number: int
    subsections: list<document_section>
}

struct extracted_table {
    id: string
    headers: list<string>
    rows: list<list<string>>
    markdown_representation: string
    html_representation: string
    caption: string
    row_count: int
    column_count: int
    source_page: int
    confidence: float
    bbox: tuple<float, float, float, float>
}

struct extracted_image {
    id: string
    data: bytes
    format: string
    alt_text: string
    width: int
    height: int
    caption: string
    position: tuple<int, int>
}

struct extracted_link {
    url: string
    text: string
    link_type: string
}

struct code_block {
    language: string
    code: string
    start_line: int
    end_line: int
}

struct document_statistics {
    total_characters: int
    total_words: int
    total_lines: int
    section_count: int
    table_count: int
    image_count: int
    code_block_count: int
    link_count: int
    estimated_reading_time_minutes: float
}
struct document_parser {
    config: document_parser_config
    pdf_parser: PDFParser
    html_parser: HTMLParser
    markdown_parser: MarkdownParser
    office_parser: OfficeDocumentParser
    init(config: document_parser_config) {
        this.config = config  new document_parser_config()
        if "pdf" in this.config.enabled_formats {
            this.pdf_parser = new pdf_parser(config=this.config)
        }
        if "html" in this.config.enabled_formats || "htm" in this.config.enabled_formats {
            this.html_parser = new html_parser(config=this.config)
        }
        if "md" in this.config.enabled_formats || "markdown" in this.config.enabled_formats {
            this.markdown_parser = new markdown_parser(config=this.config)
        }
        if {"docx", "pptx", "xlsx"}.any(f => f in this.config.enabled_formats) {
            this.office_parser = new office_document_parser(config=this.config)
        }
    }
    parse(string file_path) {
        ext = get_file_extension(file_path).to_lower()
        match ext {
            "pdf" => { return this._parse_pdf(file_path) }
            "html" | "htm" => { return this._parse_html(file_path) }
            "md" | "markdown" => { return this._parse_markdown(file_path) }
            "docx" => { return this._parse_docx(file_path) }
            "pptx" | "ppt" => { return this._parse_pptx(file_path) }
            "xlsx" | "xls" => { return this._parse_xlsx(file_path) }
            "csv" => { return this._parse_csv(file_path) }
            "txt" | "text" => { return this._parse_plain_text(file_path) }
            _ => throw error(f"Unsupported file format: {ext}")
        }
    }
    parse_string(string content, string format_hint = "markdown") {
        match format_hint.to_lower() {
            "html" | "htm" => { return this.html_parser!.parse_string(content) }
            "md" | "markdown" => { return this.markdown_parser!.parse_string(content) }
            _ => {
                return this._parse_plain_text_string(content)
            }
        }
    }
    parse_batch(file_paths: list<string>) {
        results: list<parsed_document> = []
        for path in file_paths {
            try {
                doc := this.parse(path)
                results.append(doc)
            } catch exception as e {
                print(f"Warning: Failed to parse {path}: {e.message}")
            }
        }
        return results
    }
    _parse_pdf(string file_path) {
        assert this.pdf_parser != null, "PDF parser not initialized"
        return this.pdf_parser!.parse(file_path)
    }
    _parse_html(string file_path) {
        assert this.html_parser != null, "HTML parser not initialized"
        content := read_text_file(file_path)
        return this.html_parser!.parse_string(content, source_url=file_path)
    }
    _parse_markdown(string file_path) {
        assert this.markdown_parser != null, "Markdown parser not initialized"
        content := read_text_file(file_path)
        return this.markdown_parser!.parse_string(content, source_path=file_path)
    }
    _parse_docx(string file_path) {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_docx(file_path)
    }
    _parse_pptx(string file_path) {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_pptx(file_path)
    }
    _parse_xlsx(string file_path) {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_xlsx(file_path)
    }
    _parse_csv(string file_path) {
        data = read_csv_file(file_path)
        headers = data[0] if data.length > 0 else []
        rows = data[1:]
        table = extracted_table{
            id="table_0",
            headers=headers,
            rows=rows,
            markdown_representation=format_table_as_markdown(headers, rows),
            row_count=rows.length,
            column_count=headers.length,
            confidence=1.0
        }
        content = "# CSV Data: " + get_filename(file_path) + "\n\n" + table.markdown_representation
        stats = compute_statistics(content)
        return parsed_document{
            content=content,
            metadata=document_metadata{
                filename=get_filename(file_path),
                file_path=file_path,
                file_format="csv",
                file_size_bytes=get_file_size(file_path),
                mime_type="text/csv",
                word_count=stats.total_words
            },
            sections=[document_section{
                id="sec_0",
                title="CSV Data",
                level=1,
                content=content,
                start_position=0,
                end_position=content.length
            }],
            tables=[table],
            images=[],
            links=[],
            code_blocks=[],
            statistics=stats
        }
    }
    _parse_plain_text(string file_path) {
        content = read_text_file(file_path)
        return this._parse_plain_text_string(content, source_path=file_path)
    }
    _parse_plain_text_string(string content, source_path: string) {
        stats = compute_statistics(content)
        raw_sections = content.split("\n\n")
        sections: list<document_section> = []
        pos = 0
        for i, sec_content in enumerate(raw_sections) {
            sec_len = sec_content.length
            sections.append(document_section{
                id=f"sec_{i}",
                title="",
                level=1,
                content=sec_content.trim(),
                start_position=pos,
                end_position=pos + sec_len
            })
            pos += sec_len + 2
        }
        return parsed_document{
            content=content,
            metadata=document_metadata{
                filename=source_path  get_filename(source_path!) : "unknown.txt",
                file_path=source_path  "",
                file_format="txt",
                file_size_bytes=content.encode('utf-8').length,
                mime_type="text/plain",
                word_count=stats.total_words
            },
            sections=sections,
            tables=[],
            images=[],
            links=[],
            code_blocks=[],
            statistics=stats
        }
    }
}
struct pdf_parser {
    config: document_parser_config
    init(config: document_parser_config) {
        this.config = config
    }
    parse(string file_path) {
        doc = open_pdf(file_path)
        full_text_parts: list<string> = []
        all_sections: list<document_section> = []
        all_tables: list<extracted_table> = []
        all_images: list<extracted_image> = []
        current_pos = 0
        for page_num in range(doc.page_count):
            page = doc.load_page(page_num)
            if this.config.pdf_preserve_layout {
                text_dict = page.get_text("dict")
                blocks = text_dict["blocks"]
                page_text_parts: list<string> = []
                for block in blocks:
                    if block["type"] == 0:
                        lines_text = ""
                        for line in block["lines"]:
                            line_text = "".join(span["text"] for span in line["spans"])
                            lines_text += line_text + "\n"
                        page_text_parts.append(lines_text.strip())
                        if block["lines"].length > 0 && block["lines"][0]["spans"].length > 0:
                            first_span = block["lines"][0]["spans"][0]
                            font_size = first_span["size"]
                            is_bold = "bold" in first_span["font"].to_lower()
                            if font_size > 14 && is_bold && len(lines_text.strip()) < 100:
                                all_sections.append(document_section{
                                    id=f"sec_{all_sections.length}",
                                    title=lines_text.strip(),
                                    level=min(int((font_size - 10) / 2), 6),
                                    content=lines_text.strip(),
                                    start_position=current_pos,
                                    end_position=current_pos + len(lines_text),
                                    page_number=page_num + 1
                                })
                    elif block["type"] == 1:
                        if this.config.pdf_extract_images:
                            img_data = extract_image_from_pdf_block(doc, page_num, block)
                            if img_data != null {
                                all_images.append(img_data!)
                page_text = "\n\n".join(page_text_parts)
            else:
                page_text = page.get_text()
            full_text_parts.append(page_text)
            if this.config.pdf_extract_tables {
                tables_on_page = extract_tables_from_pdf_page(page)
                all_tables.extend(tables_on_page)
            current_pos += len(page_text) + 2
        full_text = "\n\n--- Page Break ---\n\n".join(full_text_parts)
        if all_sections.empty() {
            pages_texts = full_text.split("--- Page Break ---")
            for i, pt in enumerate(pages_texts) {
                all_sections.append(document_section{
                    id=f"page_{i}",
                    title=f"Page {i + 1}",
                    level=1,
                    content=pt.trim(),
                    start_position=full_text.indexof(pt),
                    end_position=full_text.indexof(pt) + pt.length,
                    page_number=i + 1
                })
            }
        stats = compute_statistics(full_text)
        return parsed_document{
            content=full_text,
            metadata=document_metadata{
                filename=get_filename(file_path),
                file_path=file_path,
                file_format="pdf",
                file_size_bytes=get_file_size(file_path),
                mime_type="application/pdf",
                page_count=doc.page_count,
                word_count=stats.total_words
            },
            sections=all_sections,
            tables=all_tables,
            images=all_images,
            links=[],
            code_blocks=[],
            statistics={...stats, ...{"page_count": doc.page_count}}
        }
    }
    extract_tables_from_pdf_page(page: any) {
        return []
    }
    extract_image_from_pdf_block(doc: any, int page_idx, map image_block<string, any>) {
        return null
    }
}
struct html_parser {
    config: document_parser_config
    init(config: document_parser_config) {
        this.config = config
    }
    parse_string(string html_content, source_url: string) {
        soup = parse_html(html_content)
        if this.config.html_clean_html {
            for selector in this.config.html_remove_elements {
                soup.find_all(selector).each(el => el.decompose())
            }
        meta = this._extract_metadata(soup, source_url)
        if this.config.html_extract_main_content:
            main_content = this._extract_main_content(soup)
        } else:
            main_content = soup.body  soup
        result = this._convert_element(main_content, source_url)
        stats = compute_statistics(result.content)
        return parsed_document{
            content=result.content,
            metadata=meta,
            sections=result.sections,
            tables=result.tables,
            images=result.images,
            links=result.links,
            code_blocks=result.code_blocks,
            statistics=stats,
            raw_structure=soup
        }
    }
    _extract_metadata(soup: any, source_url: string) {
        title = soup.title.get_text().trim()  ""
        og_title = soup.find("meta", property="og:title").get("content")
        description = soup.find("meta", attrs={"name": "description"}).get("content")
        author_meta = soup.find("meta", attrs={"name": "author"}).get("content")
        return document_metadata{
            filename=source_url  extract_filename_from_url(source_url!) : "",
            file_path=source_url  "",
            file_format="html",
            file_size_bytes=len(source_url.encode()  b""),
            mime_type="text/html",
            title=og_title  title,
            author=author_meta,
            word_count=null
        }
    }
    _extract_main_content(soup: any) {
        candidates: list<{element: any, score: float}> = []
        for elem in soup.find_all(["div", "article", "main", "section"]) {
            score = 0.0
            text_length = len(elem.get_text())
            if text_length > 100:
                score += math.log(text_length)
            tag_name = elem.name
            if tag_name in ["article", "main"]:
                score += 25
            class_id_str = (elem.get("class", [])  []).join("") + (elem.get("id", "")  "")
            positive_terms = ["post", "article", "content", "entry", "body", "text", "story", "main"]
            for term in positive_terms:
                if term in class_id_str.to_lower():
                    score += 15
            negative_terms = ["comment", "sidebar", "footer", "header", "nav", "menu", "widget", "ad"]
            for term in negative_terms:
                if term in class_id_str.to_lower():
                    score -= 30
            links = elem.find_all("a")
            text = elem.get_text()
            if len(text) > 0 and links.length > 0:
                link_density = sum(len(link.get_text()) for link in links) / len(text)
                if link_density > 0.5:
                    score -= 20 * link_density
            if score > 0:
                candidates.append({element=elem, score=score})
        if candidates.length > 0:
            candidates.sort_by_descending(c => c.score)
            return candidates[0].element
        return soup.body  soup
    }
    _convert_element(element: any, base_url: string) {
        sections: list<document_section> = []
        tables: list<extracted_table> = []
        images: list<extracted_image> = []
        links: list<extracted_link> = []
        code_blocks: list<code_block> = []
        content_parts: list<string> = []
        pos = 0
        def process_node(node: any, int depth = 0) {
            nonlocal pos
            if node.name in ["h1", "h2", "h3", "h4", "h5", "h6"]:
                level = int(node.name[1])
                text = node.get_text().strip()
                content_parts.append("#".repeat(level) + " " + text + "\n\n")
                sections.append(document_section{
                    id=f"h{level}_{sections.length}",
                    title=text,
                    level=level,
                    content="",
                    start_position=pos,
                    end_position=pos + len(text)
                })
                pos += len("#".repeat(level) + " " + text + "\n\n")
            elif node.name == "p":
                text = clean_whitespace(node.get_text())
                if !text.empty():
                    content_parts.append(text + "\n\n")
                    pos += len(text) + 2
                    if sections.length > 0:
                        sections[-1].content += text + "\n\n"
            elif node.name == "table":
                table_result = this._extract_table(node)
                tables.append(table_result.table)
                content_parts.append(table_result.markdown + "\n\n")
                pos += len(table_result.markdown) + 2
            elif node.name == "img":
                src = node.get("src")  ""
                alt = node.get("alt")  ""
                if src.starts_with("
                    src = "https:" + src
                elif not (src.starts_with("http:
                    src = resolve_relative_url(base_url  "", src)
                images.append(extracted_image{
                    id=f"img_{images.length}",
                    data=b"",
                    format=get_extension_from_url(src),
                    alt_text=alt,
                    width=int(node.get("width", "0")),
                    height=int(node.get("height", "0")),
                    position=(pos, 0)
                })
                content_parts.append(f"![{alt}]({src})\n\n")
                pos += len(f"![{alt}]({src})\n\n")
            elif node.name == "a" and this.config.html_keep_links:
                href = node.get("href", "")
                text = node.get_text().strip()
                if !href.empty() and !text.empty():
                    link_type = "external" if href.starts_with("http") else ("anchor" if href.starts_with("#") else "internal")
                    links.append(extracted_image{url=href, text=text, link_type=link_type})
                    content_parts.append(f"[{text}]({href})")
                    pos += len(f"[{text}]({href})")
            elif node.name in ["pre", "code"]:
                lang_class = node.get("class", [])
                lang = "text"
                for cls in lang_class:
                    if cls.starts_with("language-"):
                        lang = cls[9:]
                        break
                    elif cls.starts_with("lang-"):
                        lang = cls[5:]
                        break
                code_text = node.get_text()
                code_blocks.append(code_block{
                    language=lang,
                    code=code_text,
                    start_line=0,
                    end_line=code_text.count("\n")
                })
                content_parts.append(f"\n```{lang}\n{code_text}\n```\n\n")
                pos += len(f"\n```{lang}\n{code_text}\n```\n\n")
            elif node.name in ["ul", "ol"]:
                list_items = []
                for li in node.find_all("li", recursive=false):
                    list_items.append(li.get_text().strip())
                marker = "-" if node.name == "ul" else "1."
                list_text = "\n".join(f"{marker} {item}" for item in list_items) + "\n\n"
                content_parts.append(list_text)
                pos += len(list_text)
            for child in node.children:
                process_node(child, depth + 1)
        process_node(element)
        return conversion_result{
            content="\n".join(content_parts),
            sections=sections,
            tables=tables,
            images=images,
            links=links,
            code_blocks=code_blocks
        }
    }
    _extract_table(table_elem: any) {
        headers: list<string> = []
        rows: list<list<string>> = []
        thead = table_elem.find("thead")
        if thead:
            header_row = thead.find("tr")
            if header_row:
                headers = [th.get_text().strip() for th in header_row.find_all(["th", "td"])]
        else:
            first_tr = table_elem.find("tr")
            if first_tr:
                th_cells = first_tr.find_all("th")
                td_cells = first_tr.find_all("td")
                if th_cells.length > 0:
                    headers = [th.get_text().strip() for th in th_cells]
                elif td_cells.length > 0 and this.config.table_header_detection:
                    cell_lengths = [len(td.get_text().strip()) for td in td_cells]
                    avg_length = sum(cell_lengths) / cell_lengths.length
                    if avg_length < 30:
                        headers = [td.get_text().strip() for td in td_cells]
        tbody = table_elem.find("tbody")  table_elem
        for tr in tbody.find_all("tr")[1 if (headers.length > 0 and !thead) else 0:]:
            cells: list<string> = []
            for td in tr.find_all(["td", "th"]):
                cells.append(td.get_text().strip().replace("\n", " "))
            if cells.length > 0:
                rows.append(cells)
        md_repr = format_table_as_markdown(headers, rows)
        return table_conversion_result{
            table=extracted_table{
                id=f"table_{generate_short_uuid()}",
                headers=headers,
                rows=rows,
                markdown_representation=md_repr,
                row_count=rows.length,
                column_count=headers.length,
                confidence=0.9
            },
            markdown=md_repr
        }
    }
}
struct conversion_result {
    content: string
    sections: list<document_section>
    tables: list<extracted_table>
    images: list<extracted_image>
    links: list<extracted_link>
    code_blocks: list<code_block>
}

struct table_conversion_result {
    table: extracted_table
    markdown: string
}
struct markdown_parser {
    config: document_parser_config
    init(config: document_parser_config) {
        this.config = config
    }
    parse_string(string markdown_content, source_path: string) {
        lines = markdown_content.split("\n")
        sections: list<document_section> = []
        tables: list<extracted_table> = []
        code_blocks: list<code_block> = []
        images: list<extracted_image> = []
        links: list<extracted_link> = []
        content_parts: list<string> = []
        current_section: document_section = null
        in_code_block = false
        code_lang = ""
        code_lines: list<string> = []
        code_start_line = 0
        in_table = false
        table_rows: list<list<string>> = []
        table_headers: list<string> = []
        table_start_idx = 0
        pos = 0
        i = 0
        for i < lines.length {
            line = lines[i]
            if line.startswith("```") {
                if !in_code_block:
                    in_code_block = true
                    code_lang = line[3:].strip()
                    code_lines = []
                    code_start_line = i + 1
                } else:
                    code_blocks.append(code_block{
                        language=code_lang,
                        code="\n".join(code_lines),
                        start_line=code_start_line,
                        end_line=i
                    })
                    content_parts.append("```" + code_lang + "\n" + "\n".join(code_lines) + "\n```\n\n")
                    in_code_block = false
                i++
                continue
            if in_code_block:
                code_lines.append(line)
                i++
                continue
            heading_match = regex.match(r'^(#{1,6})\s+(.+)$', line)
            if heading_match != null {
                level = heading_match.group(1).length
                title = heading_match.group(2).trim()
                if current_section != null {
                    current_section!.end_position = pos
                    sections.append(current_section!)
                current_section = document_section{
                    id=f"h{level}_{sections.length}",
                    title=title,
                    level=level,
                    content="",
                    start_position=pos,
                    end_position=0
                }
                content_parts.append(line + "\n\n")
                pos += len(line) + 2
                i++
                continue
            if line.trim().startswith("|") and "|" in line[1:]:
                if !in_table:
                    in_table = true
                    table_start_idx = i
                    table_headers = parse_table_row(line)
                separator_match = regex.match(r'^\|[\s\-:]+\|', line.trim())
                if separator_match == null:
                    row = parse_table_row(line)
                    if row.length > 0:
                        table_rows.append(row)
                i++
                continue
            else:
                if in_table and table_rows.length > 0:
                    md_table = format_table_as_markdown(table_headers, table_rows)
                    tables.append(extracted_table{
                        id=f"tbl_{tables.length}",
                        headers=table_headers,
                        rows=table_rows,
                        markdown_representation=md_table,
                        row_count=table_rows.length,
                        column_count=table_headers.length,
                        confidence=0.95
                    })
                    content_parts.append(md_table + "\n\n")
                    pos += len(md_table) + 2
                in_table = false
                table_rows = []
                table_headers = []
            img_match = regex.match(r'!\[([^\]]*)\]\(([^)]+)\)', line)
            if img_match != null {
                alt = img_match.group(1)
                url = img_match.group(2)
                images.append(extracted_image{
                    id=f"img_{images.length}",
                    data=b"",
                    format=get_extension_from_url(url),
                    alt_text=alt,
                    width=0, height=0,
                    position=(pos, i)
                })
            content_parts.append(line + "\n")
            pos += len(line) + 1
            if current_section != null:
                current_section!.content += line + "\n"
            i++
        if in_table and table_rows.length > 0:
            md_table = format_table_as_markdown(table_headers, table_rows)
            tables.append(extracted_table{
                id=f"tbl_{tables.length}", headers=table_headers, rows=table_rows,
                markdown_representation=md_table, row_count=table_rows.length,
                column_count=table_headers.length, confidence=0.95
            })
        if current_section != null:
            current_section!.end_position = pos
            sections.append(current_section!)
        if sections.empty():
            sections.append(document_section{
                id="sec_0", title="", level=1,
                content=markdown_content, start_position=0,
                end_position=markdown_content.length
            })
        full_content = "\n".join(content_parts)
        stats = compute_statistics(full_content)
        return parsed_document{
            content=full_content,
            metadata=document_metadata{
                filename=source_path  get_filename(source_path!) : "document.md",
                file_path=source_path  "", file_format="markdown",
                file_size_bytes=len(full_content.encode('utf-8')),
                mime_type="text/markdown", word_count=stats.total_words
            },
            sections=sections,
            tables=tables,
            images=images,
            links=links,
            code_blocks=code_blocks,
            statistics=stats
        }
    }
    parse_table_row(string line) {
        parts = line.split("|").filter(p => p != null).map(p => p.trim())
        return parts
    }
}
struct office_document_parser {
    config: document_parser_config
    init(config: document_parser_config) {
        this.config = config
    }
    parse_docx(string file_path) {
        doc = load_docx(file_path)
        sections: list<document_section> = []
        tables: list<extracted_table> = []
        images: list<extracted_image> = []
        content_parts: list<string> = []
        pos = 0
        para_idx = 0
        for para in doc.paragraphs:
            style_name = para.style.name if para.style else "Normal"
            text = para.text.trim()
            if text.empty():
                content_parts.append("")
                pos += 1
                para_idx++
                continue
            if style_name.starts_with("Heading") or style_name.starts_with("Title"):
                level_match = regex.search(r'\d+', style_name)
                level = int(level_match.group()) if level_match else 1
                sections.append(document_section{
                    id=f"sec_{sections.length}",
                    title=text,
                    level=level,
                    content="",
                    start_position=pos,
                    end_position=pos + len(text)
                })
                content_parts.append("#".repeat(level) + " " + text + "\n\n")
                pos += len("#".repeat(level) + " " + text + "\n\n")
            else:
                content_parts.append(text + "\n\n")
                if sections.length > 0:
                    sections[-1].content += text + "\n\n"
                pos += len(text) + 2
            para_idx++
        for t_idx, table in enumerate(doc.tables) {
            headers: list<string> = []
            rows: list<list<string>> = []
            for r_idx, row in enumerate(table.rows):
                cells: list<string> = []
                for cell in row.cells:
                    cells.append(cell.text.trim())
                if r_idx == 0:
                    headers = cells
                else:
                    rows.append(cells)
            if headers.length > 0 and rows.length > 0:
                md_table = format_table_as_markdown(headers, rows)
                tables.append(extracted_table{
                    id=f"table_{t_idx}", headers=headers, rows=rows,
                    markdown_representation=md_table,
                    row_count=rows.length, column_count=headers.length,
                    confidence=0.95
                })
                content_parts.append(md_table + "\n\n")
                pos += len(md_table) + 2
        if this.config.office_extract_embedded:
            for rel in doc.part.rels.values():
                if "image" in rel.reltype:
                    image_data = rel.target_part.blob
                    images.append(extracted_image{
                        id=f"img_{images.length}",
                        data=image_data,
                        format=guess_image_format(image_data[:4]),
                        width=0, height=0
                    })
        full_content = "\n".join(content_parts)
        stats = compute_statistics(full_content)
        return parsed_document{
            content=full_content,
            metadata=document_metadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="docx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                word_count=stats.total_words
            },
            sections=sections, tables=tables, images=images,
            links=[], code_blocks=[], statistics=stats
        }
    }
    parse_pptx(string file_path) {
        pptx = load_pptx(file_path)
        sections: list<document_section> = []
        content_parts: list<string> = []
        pos = 0
        for slide_idx, slide in enumerate(pptx.slides):
            slide_title = slide.shapes.title.text.trim()  f"Slide {slide_idx + 1}"
            shape_texts: list<string> = []
            for shape in slide.shapes:
                if hasattr(shape, "text") and shape.text.trim() != "":
                    shape_texts.append(shape.text.trim())
            slide_content = "\n".join(shape_texts)
            sections.append(document_section{
                id=f"slide_{slide_idx}",
                title=slide_title,
                level=1,
                content=slide_content,
                start_position=pos,
                end_position=pos + len(slide_content)
            })
            formatted_slide = f"## {slide_title}\n\n{slide_content}\n\n---\n\n"
            content_parts.append(formatted_slide)
            pos += len(formatted_slide)
        full_content = "\n".join(content_parts)
        stats = compute_statistics(full_content)
        return parsed_document{
            content=full_content,
            metadata=document_metadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="pptx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.presentationml.presentation",
                word_count=stats.total_words
            },
            sections=sections, tables=[], images=[], links=[],
            code_blocks=[], statistics=stats
        }
    }
    parse_xlsx(string file_path) {
        wb = load_excel(file_path)
        sheets_content: list<string> = []
        all_tables: list<extracted_table> = []
        for sheet_name, sheet in wb.items():
            sheet_data = sheet.values
            rows_list = list(sheet_data)
            if rows_list.length == 0 { continue }
            headers = [str(c)  "" for c in rows_list[0]]
            data_rows = [[str(c)  "" for c in row] for row in rows_list[1:]]
            md_table = format_table_as_markdown(headers, data_rows)
            all_tables.append(extracted_table{
                id=f"sheet_{all_tables.length}",
                headers=headers,
                rows=data_rows,
                markdown_representation=md_table,
                row_count=data_rows.length,
                column_count=headers.length,
                confidence=1.0
            })
            sheets_content.append(f"# Sheet: {sheet_name}\n\n{md_table}\n\n")
        full_content = "\n".join(sheets_content)
        stats = compute_statistics(full_content)
        return parsed_document{
            content=full_content,
            metadata=document_metadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="xlsx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                word_count=stats.total_words
            },
            sections=[document_section{
                id="sec_0", title="Excel Data", level=1,
                content=full_content, start_position=0,
                end_position=full_content.length
            }],
            tables=all_tables, images=[], links=[],
            code_blocks=[], statistics=stats
        }
    }
}
function format_table_as_markdown(headers: list<string>, rows: list<list<string>>) {
    if headers.length == 0 { return "" }
    col_widths: list<int> = []
    for h_idx, h in enumerate(headers) {
        max_w = h.length
        for row in rows:
            if h_idx < row.length:
                max_w = max(max_w, row[h_idx].length)
        col_widths.append(max_w)
    header_line = "| "
    for i, h in enumerate(headers):
        header_line += h.ljust(col_widths[i]) + " | "
    header_line = header_line.trim() + "|"
    sep_line = "| "
    for w in col_widths:
        sep_line += "-".repeat(w) + " | "
    sep_line = sep_line.trim() + "|"
    data_lines: list<string> = []
    for row in rows:
        row_line = "| "
        for c_idx, cell in enumerate(row) {
            if c_idx < col_widths.length:
                row_line += cell.ljust(col_widths[c_idx]) + " | "
            else:
                row_line += cell + " | "
        }
        data_lines.append(row_line.trim() + "|")
    return header_line + "\n" + sep_line + "\n" + "\n".join(data_lines)
}
function compute_statistics(string content) {
    char_count = content.length
    word_count = len(content.split_whitespace())
    line_count = content.count("\n") + 1
    return document_statistics{
        total_characters=char_count,
        total_words=word_count,
        total_lines=line_count,
        section_count=0,
        table_count=0,
        image_count=0,
        code_block_count=0,
        link_count=0,
        estimated_reading_time_minutes=word_count / 200.0
    }
}
function clean_whitespace(string text) {
    return regex.sub(r'\s+', ' ', text).strip()
}
function get_file_extension(string path) {
    dot_idx = path.rfind(".")
    if dot_idx >= 0 && dot_idx < path.length - 1:
        return path[dot_idx + 1:].to_lower()
    return ""
}
function generate_uuid() {
    import uuid
    return str(uuid.uuid4())
}
def generate_short_uuid() {
    import uuid, shortuuid
    return shortuuid.uuid()[:8]
function create_document_parser(config: document_parser_config) {
    return new document_parser(config=config)
}
function test_document_parser() {
    print("🧪 Testing NEURX document Parser...")
    parser = new document_parser()
    print("  ✓ Test 1: Markdown Parsing")
    sample_md = """
This is an overview of artificial intelligence.
- Machine Learning
- Deep Learning
- NLP
```python
def train_model(data):
    model.fit(data)
    return model
```
| Algorithm | Type | Accuracy |
|-----------|------|----------|
| Random Forest | Ensemble | 89% |
| Neural Network | Deep Learning | 94% |
| SVM | Kernel | 87% |
AI is transforming industries.
"""
    md_result = parser.parse_string(sample_md, "markdown")
    assert md_result.sections.length >= 3, f"Expected >=3 sections, got {md_result.sections.length}"
    assert md_result.tables.length == 1, f"Expected 1 table, got {md_result.tables.length}"
    assert md_result.code_blocks.length == 1, f"Expected 1 code block, got {md_result.code_blocks.length}"
    assert md_result.statistics.word_count > 50, f"Word count too low: {md_result.statistics.word_count}"
    print("  ✓ Test 2: HTML Parsing")
    sample_html = """
<!DOCTYPE html>
<html>
<head><title>Test Article</title></head>
<body>
<article>
<h1>Main Title</h1>
<p>This is the main article content.</p>
<h2>Subsection</h2>
<p>Detailed explanation here.</p>
<table><tr><th>Name</th><th>Value</th></tr><tr><td>A</td><td>100</td></tr></table>
</article>
<nav>Navigation menu should be removed</nav>
</body></html>
"""
    html_result = parser.parse_string(sample_html, "test.html")
    assert html_result.metadata.title == "Main Title", "Title extraction failed"
    assert html_result.sections.length >= 2, f"Expected >=2 sections, got {html_result.sections.length}"
    assert html_result.tables.length == 1, "Table extraction failed"
    assert "Navigation" not in html_result.content, "Nav element not properly removed"
    print("  ✓ Test 3: Statistics Calculation")
    stats = html_result.statistics
    assert stats.total_characters > 0, "Char count should be > 0"
    assert stats.estimated_reading_time_minutes > 0, "Reading time should be > 0"
    print("\n✅ All document Parser Tests Passed!")
    return true
}
export {
    document_parser_config, parsed_document, document_metadata,
    document_section, extracted_table, extracted_image, code_block,
    document_statistics, document_parser,
    create_document_parser, test_document_parser
}

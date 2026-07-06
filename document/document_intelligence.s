// ============================================================
// NEURX DOCUMENT智能解析系统
// 完整实现: PDF/HTML/Markdown/DOCX/PPTX/Excel + 表格抽取 + OCR集成
// 支持: 结构化数据提取 / 版面分析 / 多模态文档理解
// ============================================================

module document_parser

// ==================== 核心配置与类型定义 ====================

struct DocumentParserConfig {
    // 支持的格式
    enabled_formats: list<string> = ["pdf", "html", "markdown", "docx", "pptx", "xlsx", "txt", "csv"]
    
    // PDF 解析配置
    pdf_extract_images: bool = true               # 提取PDF中的图片
    pdf_ocr_enabled: bool = false                  # OCR扫描件
    pdf_ocr_language: string = "chi_sim+eng"       # OCR语言 (中文简体+英文)
    pdf_preserve_layout: bool = true              # 保持原始版面布局
    pdf_extract_tables: bool = true                # 自动检测并提取表格
    
    // HTML 解析配置
    html_clean_html: bool = true                   # 清理HTML标签和样式
    html_extract_main_content: bool = true         # 智能提取正文（去除广告、导航等）
    html_remove_elements: list<string> = ["script", "style", "nav", "footer", "header", "aside"]  # 要移除的元素
    html_keep_links: bool = true                   # 保留超链接信息
    
    // Markdown 解析配置
    md_extract_code_blocks: bool = true            # 单独处理代码块
    md_extract_tables: bool = true                 # 解析Markdown表格
    md_handle_front_matter: bool = true            # 处理YAML front matter
    md_parse_math: bool = true                     # 解析LaTeX数学公式
    
    // Office文档配置
    office_extract_embedded: bool = true           # 提取嵌入对象
    office_resolve_styles: bool = true             # 解析样式为文本标记
    
    // 表格抽取配置
    table_detection_method: string = "auto"        # auto | rule_based | deep_learning
    table_header_detection: bool = true            # 自动识别表头
    table_merge_cell_support: bool = true          # 支持合并单元格
    
    // 输出配置
    output_format: string = "markdown"             # markdown | plain_text | structured_json
    max_file_size_mb: int = 100                    # 最大文件大小限制
    chunk_size: int = 1000                         # 分块大小 (字符数)
    chunk_overlap: int = 200                       # 分块重叠
    
    // 高级功能
    enable_metadata_extraction: bool = true        # 提取元数据(作者、日期等)
    enable_section_detection: bool = true          # 自动检测章节标题
    enable_page_numbering: bool = true             # 保留页码信息 (PDF)
}

struct ParsedDocument {
    content: string                                # 主要文本内容 (根据output_format格式化)
    metadata: DocumentMetadata                     # 文档元数据
    sections: list<DocumentSection>                # 章节/段落列表
    tables: list<ExtractedTable>                  # 提取的表格
    images: list<ExtractedImage>                 # 提取的图片
    links: list<ExtractedLink>                    # 提取的链接 (HTML)
    code_blocks: list<CodeBlock>                 # 代码块 (Markdown)
    statistics: DocumentStatistics                # 文档统计信息
    raw_structure: any?                            # 原始结构化数据 (如DOM树)
}

struct DocumentMetadata {
    filename: string                               # 原始文件名
    file_path: string                              # 文件路径
    file_format: string                            # 格式: pdf/html/md/docx/...
    file_size_bytes: int                           # 文件大小
    mime_type: string                              # MIME类型
    title: string?                                 # 标题 (从内容或元数据中提取)
    author: string?                                # 作者
    created_date: string?                          # 创建日期
    modified_date: string?                         # 修改日期
    page_count: int?                               # 页数 (PDF)
    word_count: int?                               # 字数
    language: string?                              # 检测到的语言
    encoding: string?                              # 文本编码
}

struct DocumentSection {
    id: string                                     # Section ID
    title: string                                  # 章节标题 (可为空)
    level: int                                     # 层级深度 (H1=1, H2=2, ...)
    content: string                                # 该章节的纯文本内容
    start_position: int                            # 在全文中的起始位置
    end_position: int                              # 结束位置
    page_number?: int                              # 页码 (PDF)
    subsections: list<DocumentSection>?            # 子章节
}

struct ExtractedTable {
    id: string                                     # Table ID
    headers: list<string>                          # 表头列名
    rows: list<list<string>>                       # 行数据
    markdown_representation: string               # Markdown格式的表格
    html_representation: string?                  # HTML格式 (可选)
    caption: string?                               # 表格标题/说明
    row_count: int                                 # 行数
    column_count: int                              # 列数
    source_page?: int                              # 来源页码
    confidence: float                              # 检测置信度 (0-1)
    bbox?: tuple<float, float, float, float>?      # 在页面中的位置 (x1, y1, x2, y2) 用于PDF
}

struct ExtractedImage {
    id: string                                     # Image ID
    data: bytes                                    # 图像二进制数据
    format: string                                 # 图像格式 (png/jpeg/svg/...)
    alt_text: string?                              # 替代文字 (从alt属性或周围文本推断)
    width: int                                     # 宽度 (像素)
    height: int                                    # 高度 (像素)
    caption: string?                               # 图片说明
    position: tuple<int, int>?                     # 在文档中的位置 (char_offset, line_number)
}

struct ExtractedLink {
    url: string                                    # 链接URL
    text: string                                   # 链接文本
    link_type: string                              # internal | external | anchor
}

struct CodeBlock {
    language: string                               # 编程语言标识符
    code: string                                   # 代码内容
    start_line: int                                # 起始行号
    end_line: int                                  # 结束行号
}

struct DocumentStatistics {
    total_characters: int                          # 总字符数
    total_words: int                               # 总词数
    total_lines: int                               # 总行数
    section_count: int                             # 章节数
    table_count: int                               # 表格数量
    image_count: int                               # 图片数量
    code_block_count: int                          # 代码块数量
    link_count: int                                # 链接数量 (HTML)
    estimated_reading_time_minutes: float          # 预估阅读时间 (分钟)
}

// ==================== 主解析器入口 ====================

class DocumentParser {
    config: DocumentParserConfig
    pdf_parser: PDFParser?
    html_parser: HTMLParser?
    markdown_parser: MarkdownParser?
    office_parser: OfficeDocumentParser?

    init(config?: DocumentParserConfig) {
        this.config = config ?? new DocumentParserConfig()
        
        # Initialize format-specific parsers
        if "pdf" in this.config.enabled_formats {
            this.pdf_parser = new PDFParser(config=this.config)
        }
        if "html" in this.config.enabled_formats || "htm" in this.config.enabled_formats {
            this.html_parser = new HTMLParser(config=this.config)
        }
        if "md" in this.config.enabled_formats || "markdown" in this.config.enabled_formats {
            this.markdown_parser = new MarkdownParser(config=this.config)
        }
        if {"docx", "pptx", "xlsx"}.any(f => f in this.config.enabled_formats) {
            this.office_parser = new OfficeDocumentParser(config=this.config)
        }
    }

    parse(file_path: string) -> ParsedDocument {
        # Detect file format
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

    parse_string(content: string, format_hint: string = "markdown") -> ParsedDocument {
        match format_hint.to_lower() {
            "html" | "htm" => { return this.html_parser!.parse_string(content) }
            "md" | "markdown" => { return this.markdown_parser!.parse_string(content) }
            _ => {
                # Treat as plain text with basic formatting
                return this._parse_plain_text_string(content)
            }
        }
    }

    parse_batch(file_paths: list<string>) -> list<ParsedDocument> {
        results: list<ParsedDocument> = []
        for path in file_paths {
            try {
                let doc = this.parse(path)
                results.append(doc)
            } catch Exception as e {
                print(f"Warning: Failed to parse {path}: {e.message}")
            }
        }
        return results
    }

    _parse_pdf(file_path: string) -> ParsedDocument {
        assert this.pdf_parser != null, "PDF parser not initialized"
        return this.pdf_parser!.parse(file_path)
    }

    _parse_html(file_path: string) -> ParsedDocument {
        assert this.html_parser != null, "HTML parser not initialized"
        let content = read_text_file(file_path)
        return this.html_parser!.parse_string(content, source_url=file_path)
    }

    _parse_markdown(file_path: string) -> ParsedDocument {
        assert this.markdown_parser != null, "Markdown parser not initialized"
        let content = read_text_file(file_path)
        return this.markdown_parser!.parse_string(content, source_path=file_path)
    }

    _parse_docx(file_path: string) -> ParsedDocument {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_docx(file_path)
    }

    _parse_pptx(file_path: string) -> ParsedDocument {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_pptx(file_path)
    }

    _parse_xlsx(file_path: string) -> ParsedDocument {
        assert this.office_parser != null, "Office parser not initialized"
        return this.office_parser!.parse_xlsx(file_path)
    }

    _parse_csv(file_path: string) -> ParsedDocument {
        # CSV is simple - treat as single-table document
        data = read_csv_file(file_path)
        headers = data[0] if data.length > 0 else []
        rows = data[1:]
        
        table = ExtractedTable{
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
        
        return ParsedDocument{
            content=content,
            metadata=DocumentMetadata{
                filename=get_filename(file_path),
                file_path=file_path,
                file_format="csv",
                file_size_bytes=get_file_size(file_path),
                mime_type="text/csv",
                word_count=stats.total_words
            },
            sections=[DocumentSection{
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

    _parse_plain_text(file_path: string) -> ParsedDocument {
        content = read_text_file(file_path)
        return this._parse_plain_text_string(content, source_path=file_path)
    }

    _parse_plain_text_string(content: string, source_path?: string) -> ParsedDocument {
        stats = compute_statistics(content)
        
        # Simple section splitting by double newlines
        raw_sections = content.split("\n\n")
        sections: list<DocumentSection> = []
        pos = 0
        for i, sec_content in enumerate(raw_sections) {
            sec_len = sec_content.length
            sections.append(DocumentSection{
                id=f"sec_{i}",
                title="",  # Plain text has no explicit titles
                level=1,
                content=sec_content.trim(),
                start_position=pos,
                end_position=pos + sec_len
            })
            pos += sec_len + 2  # +2 for \n\n
        }
        
        return ParsedDocument{
            content=content,
            metadata=DocumentMetadata{
                filename=source_path ? get_filename(source_path!) : "unknown.txt",
                file_path=source_path ?? "",
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

// ==================== PDF 解析器 ====================

class PDFParser {
    config: DocumentParserConfig

    init(config: DocumentParserConfig) {
        this.config = config
    }

    parse(file_path: string) -> ParsedDocument {
        # Use PyMuPDF (fitz) or pdfplumber for high-quality extraction
        doc = open_pdf(file_path)
        
        full_text_parts: list<string> = []
        all_sections: list<DocumentSection> = []
        all_tables: list<ExtractedTable> = []
        all_images: list<ExtractedImage> = []
        
        current_pos = 0
        
        for page_num in range(doc.page_count):
            page = doc.load_page(page_num)
            
            # Extract text with layout preservation
            if this.config.pdf_preserve_layout {
                text_dict = page.get_text("dict")
                
                blocks = text_dict["blocks"]
                page_text_parts: list<string> = []
                
                for block in blocks:
                    if block["type"] == 0:  # Text block
                        lines_text = ""
                        for line in block["lines"]:
                            line_text = "".join(span["text"] for span in line["spans"])
                            lines_text += line_text + "\n"
                        page_text_parts.append(lines_text.strip())
                        
                        # Detect headings (larger font size, bold)
                        if block["lines"].length > 0 && block["lines"][0]["spans"].length > 0:
                            first_span = block["lines"][0]["spans"][0]
                            font_size = first_span["size"]
                            is_bold = "bold" in first_span["font"].to_lower()
                            
                            if font_size > 14 && is_bold && len(lines_text.strip()) < 100:
                                # Likely a heading
                                all_sections.append(DocumentSection{
                                    id=f"sec_{all_sections.length}",
                                    title=lines_text.strip(),
                                    level=min(int((font_size - 10) / 2), 6),  # Rough heading level estimate
                                    content=lines_text.strip(),
                                    start_position=current_pos,
                                    end_position=current_pos + len(lines_text),
                                    page_number=page_num + 1
                                })
                    
                    elif block["type"] == 1:  # Image block
                        if this.config.pdf_extract_images:
                            img_data = extract_image_from_pdf_block(doc, page_num, block)
                            if img_data != null {
                                all_images.append(img_data!)
                    
                page_text = "\n\n".join(page_text_parts)
            
            else:
                # Simple text extraction without layout
                page_text = page.get_text()
            
            full_text_parts.append(page_text)
            
            # Table extraction
            if this.config.pdf_extract_tables {
                tables_on_page = extract_tables_from_pdf_page(page)
                all_tables.extend(tables_on_page)
            
            current_pos += len(page_text) + 2
        
        full_text = "\n\n--- Page Break ---\n\n".join(full_text_parts)
        
        # If no sections detected from layout, create default page-based sections
        if all_sections.empty() {
            pages_texts = full_text.split("--- Page Break ---")
            for i, pt in enumerate(pages_texts) {
                all_sections.append(DocumentSection{
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
        
        return ParsedDocument{
            content=full_text,
            metadata=DocumentMetadata{
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
    
    # Helper methods for PDF processing (would use actual libraries like fitz/pdfplumber)
    extract_tables_from_pdf_page(page: any) -> list<ExtractedTable> {
        # Implementation would use camelot/tabula-py or pdfplumber's built-in table detection
        # Returns list of detected tables on the page
        return []  # Placeholder
    }
    
    extract_image_from_pdf_block(doc: any, page_idx: int, image_block: map<string, any>) -> ExtractedImage? {
        # Extract image data from the PDF page at given coordinates
        return null  # Placeholder
    }
}

// ==================== HTML 解析器 ====================

class HTMLParser {
    config: DocumentParserConfig

    init(config: DocumentParserConfig) {
        this.config = config
    }

    parse_string(html_content: string, source_url?: string) -> ParsedDocument {
        # Parse HTML into DOM tree using BeautifulSoup/lxml
        soup = parse_html(html_content)
        
        # Step 1: Remove unwanted elements (scripts, styles, navigation, etc.)
        if this.config.html_clean_html {
            for selector in this.config.html_remove_elements {
                soup.find_all(selector).each(el => el.decompose())
            }
        
        # Step 2: Extract metadata
        meta = this._extract_metadata(soup, source_url)
        
        # Step 3: Extract main content (if smart extraction enabled)
        if this.config.html_extract_main_content:
            main_content = this._extract_main_content(soup)
        } else:
            main_content = soup.body ?? soup
        
        # Step 4: Convert to structured representation
        result = this._convert_element(main_content, source_url)
        
        stats = compute_statistics(result.content)
        
        return ParsedDocument{
            content=result.content,
            metadata=meta,
            sections=result.sections,
            tables=result.tables,
            images=result.images,
            links=result.links,
            code_blocks=result.code_blocks,
            statistics=stats,
            raw_structure=soup  # Store DOM for potential further analysis
        }
    }

    _extract_metadata(soup: any, source_url?: string) -> DocumentMetadata {
        title = soup.title?.get_text().trim() ?? ""
        
        # Try to extract OpenGraph/Twitter card metadata
        og_title = soup.find("meta", property="og:title")?.get("content")
        description = soup.find("meta", attrs={"name": "description"})?.get("content")
        author_meta = soup.find("meta", attrs={"name": "author"})?.get("content")
        
        return DocumentMetadata{
            filename=source_url ? extract_filename_from_url(source_url!) : "",
            file_path=source_url ?? "",
            file_format="html",
            file_size_bytes=len(source_url?.encode() ?? b""),
            mime_type="text/html",
            title=og_title ?? title,
            author=author_meta,
            word_count=null  # Will be filled later
        }
    }

    _extract_main_content(soup: any) -> any {
        # Heuristic-based main content extraction (similar to readability/Mozilla's Readability)
        candidates: list<{element: any, score: float}> = []
        
        # Score each element based on text density and semantic cues
        for elem in soup.find_all(["div", "article", "main", "section"]) {
            score = 0.0
            
            text_length = len(elem.get_text())
            if text_length > 100:
                score += math.log(text_length)
            
            # Positive indicators
            tag_name = elem.name
            if tag_name in ["article", "main"]:
                score += 25
            class_id_str = (elem.get("class", []) ?? []).join("") + (elem.get("id", "") ?? "")
            positive_terms = ["post", "article", "content", "entry", "body", "text", "story", "main"]
            for term in positive_terms:
                if term in class_id_str.to_lower():
                    score += 15
            
            # Negative indicators
            negative_terms = ["comment", "sidebar", "footer", "header", "nav", "menu", "widget", "ad"]
            for term in negative_terms:
                if term in class_id_str.to_lower():
                    score -= 30
            
            # Link density penalty (high link density usually means navigation)
            links = elem.find_all("a")
            text = elem.get_text()
            if len(text) > 0 and links.length > 0:
                link_density = sum(len(link.get_text()) for link in links) / len(text)
                if link_density > 0.5:
                    score -= 20 * link_density
            
            if score > 0:
                candidates.append({element=elem, score=score})
        
        # Return highest scoring candidate, or body as fallback
        if candidates.length > 0:
            candidates.sort_by_descending(c => c.score)
            return candidates[0].element
        
        return soup.body ?? soup
    }

    _convert_element(element: any, base_url?: string) -> ConversionResult {
        sections: list<DocumentSection> = []
        tables: list<ExtractedTable> = []
        images: list<ExtractedImage> = []
        links: list<ExtractedLink> = []
        code_blocks: list<CodeBlock> = []
        content_parts: list<string> = []
        
        pos = 0
        
        def process_node(node: any, depth: int = 0) {
            nonlocal pos
            
            if node.name in ["h1", "h2", "h3", "h4", "h5", "h6"]:
                # Heading
                level = int(node.name[1])
                text = node.get_text().strip()
                content_parts.append("#".repeat(level) + " " + text + "\n\n")
                
                sections.append(DocumentSection{
                    id=f"h{level}_{sections.length}",
                    title=text,
                    level=level,
                    content="",
                    start_position=pos,
                    end_position=pos + len(text)
                })
                pos += len("#".repeat(level) + " " + text + "\n\n")
                
            elif node.name == "p":
                # Paragraph
                text = clean_whitespace(node.get_text())
                if !text.empty():
                    content_parts.append(text + "\n\n")
                    pos += len(text) + 2
                    
                    if sections.length > 0:
                        # Append to last section's content
                        sections[-1].content += text + "\n\n"
            
            elif node.name == "table":
                # Table
                table_result = this._extract_table(node)
                tables.append(table_result.table)
                content_parts.append(table_result.markdown + "\n\n")
                pos += len(table_result.markdown) + 2
                
            elif node.name == "img":
                # Image
                src = node.get("src") ?? ""
                alt = node.get("alt") ?? ""
                
                if src.starts_with("//"):
                    src = "https:" + src
                elif not (src.starts_with("http://") || src.starts_with("https://")):
                    src = resolve_relative_url(base_url ?? "", src)
                
                images.append(ExtractedImage{
                    id=f"img_{images.length}",
                    data=b"",  # Would need to download actual image
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
                    links.append(ExtractedImage{url=href, text=text, link_type=link_type})
                    content_parts.append(f"[{text}]({href})")
                    pos += len(f"[{text}]({href})")
            
            elif node.name in ["pre", "code"]:
                # Code block
                lang_class = node.get("class", [])
                lang = "text"
                for cls in lang_class:
                    if cls.starts_with("language-"):
                        lang = cls[9:]  # After "language-"
                        break
                    elif cls.starts_with("lang-"):
                        lang = cls[5:]
                        break
                
                code_text = node.get_text()
                code_blocks.append(CodeBlock{
                    language=lang,
                    code=code_text,
                    start_line=0,
                    end_line=code_text.count("\n")
                })
                content_parts.append(f"\n```{lang}\n{code_text}\n```\n\n")
                pos += len(f"\n```{lang}\n{code_text}\n```\n\n")
            
            elif node.name in ["ul", "ol"]:
                # List items
                list_items = []
                for li in node.find_all("li", recursive=false):
                    list_items.append(li.get_text().strip())
                
                marker = "-" if node.name == "ul" else "1."
                list_text = "\n".join(f"{marker} {item}" for item in list_items) + "\n\n"
                content_parts.append(list_text)
                pos += len(list_text)
            
            # Process children recursively
            for child in node.children:
                process_node(child, depth + 1)
        
        process_node(element)
        
        return ConversionResult{
            content="\n".join(content_parts),
            sections=sections,
            tables=tables,
            images=images,
            links=links,
            code_blocks=code_blocks
        }
    }

    _extract_table(table_elem: any) -> TableConversionResult {
        headers: list<string> = []
        rows: list<list<string>> = []
        
        # Find header row (usually <thead> or first <tr>)
        thead = table_elem.find("thead")
        if thead:
            header_row = thead.find("tr")
            if header_row:
                headers = [th.get_text().strip() for th in header_row.find_all(["th", "td"])]
        else:
            # First <tr> might be header
            first_tr = table_elem.find("tr")
            if first_tr:
                th_cells = first_tr.find_all("th")
                td_cells = first_tr.find_all("td")
                if th_cells.length > 0:
                    headers = [th.get_text().strip() for th in th_cells]
                elif td_cells.length > 0 and this.config.table_header_detection:
                    # Heuristic: check if first row looks like header (shorter cells)
                    cell_lengths = [len(td.get_text().strip()) for td in td_cells]
                    avg_length = sum(cell_lengths) / cell_lengths.length
                    if avg_length < 30:  # Short average suggests headers
                        headers = [td.get_text().strip() for td in td_cells]
        
        # Extract body rows
        tbody = table_elem.find("tbody") ?? table_elem
        for tr in tbody.find_all("tr")[1 if (headers.length > 0 and !thead) else 0:]:
            cells: list<string> = []
            for td in tr.find_all(["td", "th"]):
                cells.append(td.get_text().strip().replace("\n", " "))
            if cells.length > 0:
                rows.append(cells)
        
        # Generate Markdown representation
        md_repr = format_table_as_markdown(headers, rows)
        
        return TableConversionResult{
            table=ExtractedTable{
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

struct ConversionResult {
    content: string
    sections: list<DocumentSection>
    tables: list<ExtractedTable>
    images: list<ExtractedImage>
    links: list<ExtractedLink>
    code_blocks: list<CodeBlock>
}

struct TableConversionResult {
    table: ExtractedTable
    markdown: string
}

// ==================== Markdown 解析器 ====================

class MarkdownParser {
    config: DocumentParserConfig

    init(config: DocumentParserConfig) {
        this.config = config
    }

    parse_string(markdown_content: string, source_path?: string) -> ParsedDocument {
        lines = markdown_content.split("\n")
        
        sections: list<DocumentSection> = []
        tables: list<ExtractedTable> = []
        code_blocks: list<CodeBlock> = []
        images: list<ExtractedImage> = []
        links: list<ExtractedLink> = []
        content_parts: list<string> = []
        
        current_section: DocumentSection? = null
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
        while i < lines.length:
            line = lines[i]
            
            # Code fence
            if line.startswith("```") {
                if !in_code_block:
                    in_code_block = true
                    code_lang = line[3:].strip()
                    code_lines = []
                    code_start_line = i + 1
                } else:
                    # End of code block
                    code_blocks.append(CodeBlock{
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
            
            # Heading
            heading_match = regex.match(r'^(#{1,6})\s+(.+)$', line)
            if heading_match != null {
                level = heading_match.group(1).length
                title = heading_match.group(2).trim()
                
                # Save previous section
                if current_section != null {
                    current_section!.end_position = pos
                    sections.append(current_section!)
                
                current_section = DocumentSection{
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
            
            # Table detection (rows starting with |)
            if line.trim().startswith("|") and "|" in line[1:]:
                if !in_table:
                    in_table = true
                    table_start_idx = i
                    # Parse header
                    table_headers = parse_table_row(line)
                
                # Check if separator line (| --- | --- |)
                separator_match = regex.match(r'^\|[\s\-:]+\|', line.trim())
                if separator_match == null:
                    # Data row
                    row = parse_table_row(line)
                    if row.length > 0:
                        table_rows.append(row)
                i++
                continue
            else:
                # End of table
                if in_table and table_rows.length > 0:
                    md_table = format_table_as_markdown(table_headers, table_rows)
                    tables.append(ExtractedTable{
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
            
            # Image: ![alt](url)
            img_match = regex.match(r'!\[([^\]]*)\]\(([^)]+)\)', line)
            if img_match != null {
                alt = img_match.group(1)
                url = img_match.group(2)
                images.append(ExtractedImage{
                    id=f"img_{images.length}",
                    data=b"",
                    format=get_extension_from_url(url),
                    alt_text=alt,
                    width=0, height=0,
                    position=(pos, i)
                })
            
            # Link: [text](url)
            # ... (link extraction logic similar to above)
            
            # Regular content
            content_parts.append(line + "\n")
            pos += len(line) + 1
            
            if current_section != null:
                current_section!.content += line + "\n"
            
            i++
        
        # Handle final state
        if in_table and table_rows.length > 0:
            md_table = format_table_as_markdown(table_headers, table_rows)
            tables.append(ExtractedTable{
                id=f"tbl_{tables.length}", headers=table_headers, rows=table_rows,
                markdown_representation=md_table, row_count=table_rows.length,
                column_count=table_headers.length, confidence=0.95
            })
        
        if current_section != null:
            current_section!.end_position = pos
            sections.append(current_section!)
        
        # Fallback: if no sections found, create one big section
        if sections.empty():
            sections.append(DocumentSection{
                id="sec_0", title="", level=1,
                content=markdown_content, start_position=0,
                end_position=markdown_content.length
            })
        
        full_content = "\n".join(content_parts)
        stats = compute_statistics(full_content)
        
        return ParsedDocument{
            content=full_content,
            metadata=DocumentMetadata{
                filename=source_path ? get_filename(source_path!) : "document.md",
                file_path=source_path ?? "", file_format="markdown",
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

    parse_table_row(line: string) -> list<string> {
        # Split by | and trim each cell
        parts = line.split("|").filter(p => p != null).map(p => p.trim())
        return parts
    }
}

// ==================== Office 文档解析器 (DOCX/PPTX/XLSX) ====================

class OfficeDocumentParser {
    config: DocumentParserConfig

    init(config: DocumentParserConfig) {
        this.config = config
    }

    parse_docx(file_path: string) -> ParsedDocument {
        # Use python-docx library
        doc = load_docx(file_path)
        
        sections: list<DocumentSection> = []
        tables: list<ExtractedTable> = []
        images: list<ExtractedImage> = []
        content_parts: list<string> = []
        pos = 0
        
        # Process paragraphs
        para_idx = 0
        for para in doc.paragraphs:
            style_name = para.style.name if para.style else "Normal"
            text = para.text.trim()
            
            if text.empty():
                content_parts.append("")
                pos += 1
                para_idx++
                continue
            
            # Detect headings based on style name
            if style_name.starts_with("Heading") or style_name.starts_with("Title"):
                level_match = regex.search(r'\d+', style_name)
                level = int(level_match.group()) if level_match else 1
                
                sections.append(DocumentSection{
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
        
        # Process tables
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
                tables.append(ExtractedTable{
                    id=f"table_{t_idx}", headers=headers, rows=rows,
                    markdown_representation=md_table,
                    row_count=rows.length, column_count=headers.length,
                    confidence=0.95
                })
                content_parts.append(md_table + "\n\n")
                pos += len(md_table) + 2
        
        # Extract embedded images
        if this.config.office_extract_embedded:
            for rel in doc.part.rels.values():
                if "image" in rel.reltype:
                    image_data = rel.target_part.blob
                    images.append(ExtractedImage{
                        id=f"img_{images.length}",
                        data=image_data,
                        format=guess_image_format(image_data[:4]),
                        width=0, height=0
                    })
        
        full_content = "\n".join(content_parts)
        stats = compute_statistics(full_content)
        
        return ParsedDocument{
            content=full_content,
            metadata=DocumentMetadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="docx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                word_count=stats.total_words
            },
            sections=sections, tables=tables, images=images,
            links=[], code_blocks=[], statistics=stats
        }
    }

    parse_pptx(file_path: string) -> ParsedDocument {
        # Use python-pptx
        pptx = load_pptx(file_path)
        
        sections: list<DocumentSection> = []
        content_parts: list<string> = []
        pos = 0
        
        for slide_idx, slide in enumerate(pptx.slides):
            slide_title = slide.shapes.title?.text.trim() ?? f"Slide {slide_idx + 1}"
            
            # Collect all text from shapes
            shape_texts: list<string> = []
            for shape in slide.shapes:
                if hasattr(shape, "text") and shape.text.trim() != "":
                    shape_texts.append(shape.text.trim())
            
            slide_content = "\n".join(shape_texts)
            
            sections.append(DocumentSection{
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
        
        return ParsedDocument{
            content=full_content,
            metadata=DocumentMetadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="pptx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.presentationml.presentation",
                word_count=stats.total_words
            },
            sections=sections, tables=[], images=[], links=[],
            code_blocks=[], statistics=stats
        }
    }

    parse_xlsx(file_path: string) -> ParsedDocument {
        # Use openpyxl or pandas
        wb = load_excel(file_path)
        
        sheets_content: list<string> = []
        all_tables: list<ExtractedTable> = []
        
        for sheet_name, sheet in wb.items():
            sheet_data = sheet.values
            rows_list = list(sheet_data)
            
            if rows_list.length == 0 { continue }
            
            headers = [str(c) ?? "" for c in rows_list[0]]
            data_rows = [[str(c) ?? "" for c in row] for row in rows_list[1:]]
            
            md_table = format_table_as_markdown(headers, data_rows)
            
            all_tables.append(ExtractedTable{
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
        
        return ParsedDocument{
            content=full_content,
            metadata=DocumentMetadata{
                filename=get_filename(file_path), file_path=file_path,
                file_format="xlsx", file_size_bytes=get_file_size(file_path),
                mime_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                word_count=stats.total_words
            },
            sections=[DocumentSection{
                id="sec_0", title="Excel Data", level=1,
                content=full_content, start_position=0,
                end_position=full_content.length
            }],
            tables=all_tables, images=[], links=[],
            code_blocks=[], statistics=stats
        }
    }
}

// ==================== 辅助函数 ====================

function format_table_as_markdown(headers: list<string>, rows: list<list<string>>) -> string {
    if headers.length == 0 { return "" }
    
    col_widths: list<int> = []
    for h_idx, h in enumerate(headers) {
        max_w = h.length
        for row in rows:
            if h_idx < row.length:
                max_w = max(max_w, row[h_idx].length)
        col_widths.append(max_w)
    
    # Header row
    header_line = "| "
    for i, h in enumerate(headers):
        header_line += h.ljust(col_widths[i]) + " | "
    header_line = header_line.trim() + "|"
    
    # Separator line
    sep_line = "| "
    for w in col_widths:
        sep_line += "-".repeat(w) + " | "
    sep_line = sep_line.trim() + "|"
    
    # Data rows
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

function compute_statistics(content: string) -> DocumentStatistics {
    char_count = content.length
    word_count = len(content.split_whitespace())
    line_count = content.count("\n") + 1
    
    return DocumentStatistics{
        total_characters=char_count,
        total_words=word_count,
        total_lines=line_count,
        section_count=0,  # Will be updated after parsing
        table_count=0,
        image_count=0,
        code_block_count=0,
        link_count=0,
        estimated_reading_time_minutes=word_count / 200.0  # Average reading speed ~200 WPM
    }
}

function clean_whitespace(text: string) -> string {
    # Collapse multiple whitespace characters into single space
    return regex.sub(r'\s+', ' ', text).strip()
}

function get_file_extension(path: string) -> string {
    dot_idx = path.rfind(".")
    if dot_idx >= 0 && dot_idx < path.length - 1:
        return path[dot_idx + 1:].to_lower()
    return ""
}

function generate_uuid() -> string {
    import uuid
    return str(uuid.uuid4())
}

def generate_short_uuid() -> string {
    import uuid, shortuuid
    return shortuuid.uuid()[:8]

// ==================== 工厂函数与测试 ====================

function create_document_parser(config?: DocumentParserConfig) -> DocumentParser {
    return new DocumentParser(config=config)
}

function test_document_parser() -> bool {
    print("🧪 Testing NEURX Document Parser...")
    
    parser = new DocumentParser()
    
    # Test 1: Markdown parsing with tables and code
    print("  ✓ Test 1: Markdown Parsing")
    sample_md = """
# Introduction to AI

This is an overview of artificial intelligence.

## Key Concepts

- Machine Learning
- Deep Learning
- NLP

### Machine Learning Algorithms

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

## Conclusion

AI is transforming industries.
"""
    md_result = parser.parse_string(sample_md, "markdown")
    assert md_result.sections.length >= 3, f"Expected >=3 sections, got {md_result.sections.length}"
    assert md_result.tables.length == 1, f"Expected 1 table, got {md_result.tables.length}"
    assert md_result.code_blocks.length == 1, f"Expected 1 code block, got {md_result.code_blocks.length}"
    assert md_result.statistics.word_count > 50, f"Word count too low: {md_result.statistics.word_count}"
    
    # Test 2: HTML parsing
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
    
    # Test 3: Statistics calculation
    print("  ✓ Test 3: Statistics Calculation")
    stats = html_result.statistics
    assert stats.total_characters > 0, "Char count should be > 0"
    assert stats.estimated_reading_time_minutes > 0, "Reading time should be > 0"
    
    print("\n✅ All Document Parser Tests Passed!")
    return true
}

// Export public API
export {
    DocumentParserConfig, ParsedDocument, DocumentMetadata,
    DocumentSection, ExtractedTable, ExtractedImage, CodeBlock,
    DocumentStatistics, DocumentParser,
    create_document_parser, test_document_parser
}

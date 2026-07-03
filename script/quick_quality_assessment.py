#!/usr/bin/env python3
"""
quick_quality_assessment.py
快速数据质量评估工具
"""

import json
import sys
import argparse
from collections import defaultdict
import re
import hashlib
from pathlib import Path


class QuickQualityAssessor:
    """快速质量评估工具"""
    
    def __init__(self, sample_size=1000):
        self.sample_size = sample_size
        self.results = defaultdict(list)
    
    def assess_file(self, filepath):
        """评估单个文件"""
        print(f"📊 评估文件: {filepath}")
        
        stats = {
            'total_lines': 0,
            'valid_docs': 0,
            'invalid_docs': 0,
            'total_chars': 0,
            'total_tokens': 0,
            'length_dist': defaultdict(int),
            'quality_dist': defaultdict(int),
            'errors': []
        }
        
        try:
            with open(filepath) as f:
                for line_no, line in enumerate(f):
                    if line_no >= self.sample_size:
                        break
                    
                    stats['total_lines'] += 1
                    
                    try:
                        doc = json.loads(line)
                        text = doc.get('text', '')
                        
                        # 基础检查
                        if not text:
                            stats['invalid_docs'] += 1
                            continue
                        
                        # 长度检查
                        length = len(text)
                        if length < 100 or length > 100000:
                            stats['invalid_docs'] += 1
                            stats['length_dist']['out_of_range'] += 1
                            continue
                        
                        # 质量评分
                        quality_score = self._assess_quality(text)
                        
                        if quality_score > 0.6:
                            stats['valid_docs'] += 1
                            stats['quality_dist']['passed'] += 1
                        else:
                            stats['invalid_docs'] += 1
                            stats['quality_dist']['failed'] += 1
                        
                        # 统计
                        stats['total_chars'] += length
                        stats['total_tokens'] += length // 4
                        
                        # 长度分布
                        if length < 500:
                            stats['length_dist']['<500'] += 1
                        elif length < 5000:
                            stats['length_dist']['500-5K'] += 1
                        elif length < 20000:
                            stats['length_dist']['5K-20K'] += 1
                        else:
                            stats['length_dist']['20K+'] += 1
                    
                    except json.JSONDecodeError as e:
                        stats['invalid_docs'] += 1
                        stats['errors'].append(f"Line {line_no}: JSON parse error")
                    except Exception as e:
                        stats['invalid_docs'] += 1
                        stats['errors'].append(f"Line {line_no}: {str(e)}")
        
        except IOError as e:
            print(f"❌ 无法读取文件: {e}")
            return None
        
        return stats
    
    def _assess_quality(self, text):
        """评估文本质量 (0-1)"""
        
        score = 0.0
        
        # 1. 字母占比 (0-1)
        letters = sum(1 for c in text if c.isalpha())
        letter_ratio = letters / len(text) if text else 0
        if 0.6 < letter_ratio < 0.9:
            score += 0.3
        elif 0.4 < letter_ratio < 0.95:
            score += 0.2
        
        # 2. 单词平均长度 (0-1)
        words = re.findall(r'\b\w+\b', text)
        if words:
            avg_word_len = sum(len(w) for w in words) / len(words)
            if 4 < avg_word_len < 7:
                score += 0.3
            elif 3 < avg_word_len < 8:
                score += 0.2
        
        # 3. 多样性 (0-1)
        unique_chars = len(set(text))
        char_diversity = unique_chars / len(text)
        if char_diversity > 0.3:
            score += 0.2
        
        # 4. 噪音检查 (0-1)
        noise = 0
        if len(re.findall(r'https?://', text)) > 0:
            noise += 0.1
        if len(re.findall(r'\S+@\S+\.\S+', text)) > 0:
            noise += 0.1
        if sum(1 for c in text if not c.isprintable()) / len(text) > 0.05:
            noise += 0.2
        
        score += max(0.2 - noise, 0)
        
        return min(score, 1.0)
    
    def print_report(self, filepath, stats):
        """打印评估报告"""
        
        if not stats:
            return
        
        print("\n" + "="*60)
        print(f"📈 质量评估报告: {Path(filepath).name}")
        print("="*60)
        
        print("\n📊 基础统计:")
        print(f"  总行数: {stats['total_lines']:,}")
        print(f"  有效文档: {stats['valid_docs']:,} ({stats['valid_docs']/stats['total_lines']*100:.1f}%)")
        print(f"  无效文档: {stats['invalid_docs']:,} ({stats['invalid_docs']/stats['total_lines']*100:.1f}%)")
        
        print("\n📏 长度分布:")
        for length_range, count in sorted(stats['length_dist'].items()):
            print(f"  {length_range}: {count:,} ({count/stats['total_lines']*100:.1f}%)")
        
        print("\n✅ 质量分布:")
        for quality_level, count in stats['quality_dist'].items():
            print(f"  {quality_level}: {count:,} ({count/stats['total_lines']*100:.1f}%)")
        
        print("\n💾 大小估算:")
        print(f"  总字符: {stats['total_chars']:,} ({stats['total_chars']/1e6:.1f}M)")
        print(f"  预估 tokens: {stats['total_tokens']:,} ({stats['total_tokens']/1e9:.1f}B)")
        
        if stats['errors']:
            print(f"\n⚠️  错误 ({len(stats['errors'])}):")
            for error in stats['errors'][:5]:
                print(f"  - {error}")
            if len(stats['errors']) > 5:
                print(f"  ... 还有 {len(stats['errors'])-5} 个错误")
        
        print("\n" + "="*60)
    
    def assess_directory(self, directory):
        """评估目录下的所有 JSONL 文件"""
        
        directory = Path(directory)
        jsonl_files = list(directory.glob("*.jsonl"))
        
        if not jsonl_files:
            print(f"❌ 在 {directory} 中找不到 JSONL 文件")
            return
        
        print(f"📁 评估目录: {directory}")
        print(f"📄 找到 {len(jsonl_files)} 个 JSONL 文件\n")
        
        total_stats = {
            'files': 0,
            'total_docs': 0,
            'valid_docs': 0,
            'total_tokens': 0
        }
        
        for filepath in sorted(jsonl_files):
            stats = self.assess_file(filepath)
            if stats:
                self.print_report(filepath, stats)
                
                total_stats['files'] += 1
                total_stats['total_docs'] += stats['total_lines']
                total_stats['valid_docs'] += stats['valid_docs']
                total_stats['total_tokens'] += stats['total_tokens']
        
        # 打印总结
        print("\n" + "="*60)
        print("🎯 总体统计")
        print("="*60)
        print(f"\n文件数: {total_stats['files']}")
        print(f"总文档: {total_stats['total_docs']:,}")
        print(f"有效文档: {total_stats['valid_docs']:,} ({total_stats['valid_docs']/total_stats['total_docs']*100:.1f}%)")
        print(f"预估 tokens: {total_stats['total_tokens']/1e9:.1f}B")
        
        if total_stats['total_tokens'] > 0:
            if total_stats['total_tokens'] < 100e9:
                print(f"\n⚠️  数据规模较小，建议继续收集数据")
            elif total_stats['total_tokens'] < 1e12:
                print(f"\n💡 数据规模足够用于演示，建议扩展至 1-2T tokens 用于完整训练")
            else:
                print(f"\n✅ 数据规模充分，可以开始训练")
        
        print("\n" + "="*60)


def main():
    parser = argparse.ArgumentParser(description='快速数据质量评估工具')
    parser.add_argument('path', help='评估的文件或目录路径')
    parser.add_argument('--sample-size', type=int, default=1000, help='采样大小 (默认: 1000)')
    
    args = parser.parse_args()
    
    assessor = QuickQualityAssessor(sample_size=args.sample_size)
    
    path = Path(args.path)
    if path.is_file():
        stats = assessor.assess_file(path)
        if stats:
            assessor.print_report(path, stats)
    elif path.is_dir():
        assessor.assess_directory(path)
    else:
        print(f"❌ 路径不存在: {args.path}")
        sys.exit(1)


if __name__ == '__main__':
    main()

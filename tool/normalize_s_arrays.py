#!/usr/bin/env python3
"""Check/migrate S array types. Artifact/compiler/recovery trees are never edited.

Only code tokens are rewritten; comments, strings, raw templates and indices
remain byte-for-byte intact. Prefix dimensions are reversed when moved after
the element type, retaining the original outer-to-inner layout.
"""
import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess

PRIMITIVES={'float','int','string','bool','f32','f64','i32','i64','float32','float64','int32','int64','byte'}

@dataclass
class Token:
    text: str
    start: int
    end: int
    kind: str = 'punctuation'

def tokens(source):
    result=[];i=0;n=len(source)
    while i<n:
        begin=i;ch=source[i]
        if ch.isspace():i+=1;continue
        if source.startswith('//',i):
            i=source.find('\n',i)
            if i<0:i=n
            continue
        if source.startswith('/*',i):
            i+=2;depth=1
            while i<n and depth:
                if source.startswith('/*',i):depth+=1;i+=2
                elif source.startswith('*/',i):depth-=1;i+=2
                else:i+=1
            continue
        if ch in ('"',"'",'`'):
            quote=ch;i+=1
            while i<n:
                if source[i]=='\n' and quote!='`':break
                if source[i]=='\\' and quote!='`':i+=2
                elif source[i]==quote:i+=1;break
                else:i+=1
            result.append(Token(source[begin:i],begin,i,'literal'));continue
        if ch.isalpha() or ch=='_':
            i+=1
            while i<n and (source[i].isalnum() or source[i]=='_'):i+=1
            result.append(Token(source[begin:i],begin,i,'identifier'));continue
        if ch.isdigit():
            i+=1
            while i<n and (source[i].isalnum() or source[i]=='_'):i+=1
            result.append(Token(source[begin:i],begin,i,'number'));continue
        result.append(Token(ch,i,i+1));i+=1
    return result

class Normalizer:
    def __init__(self,source):
        self.source=source;self.ts=tokens(source)
        self.declared_types={self.ts[i+1].text for i,t in enumerate(self.ts[:-1]) if t.text in ('struct','enum','type','trait') and self.ts[i+1].kind=='identifier'}
    def at(self,i,text):return i<len(self.ts) and self.ts[i].text==text
    def dimension(self,i):
        if not self.at(i,'['):return None
        if self.at(i+1,']'):return i+2,self.source[self.ts[i].start:self.ts[i+1].end]
        if i+2<len(self.ts) and self.ts[i+1].kind=='number' and self.at(i+2,']'):
            return i+3,self.source[self.ts[i].start:self.ts[i+2].end]
        return None
    def balanced(self,i,opening,closing):
        if not self.at(i,opening):return None
        depth=1;j=i+1
        while j<len(self.ts):
            if self.at(j,opening):depth+=1
            elif self.at(j,closing):
                depth-=1
                if depth==0:return j+1
            j+=1
        return None
    def comma_in_bracket(self,i):
        end=self.balanced(i,'[',']')
        if end is None:return False
        depth=0
        for token in self.ts[i:end]:
            if token.text=='[':depth+=1
            elif token.text==']':depth-=1
            elif token.text==',' and depth==1:return True
        return False
    def type(self,i):
        start=i;dimensions=[];gaps=""
        while (dimension:=self.dimension(i)) is not None:
            i,shape=dimension;dimensions.append(shape)
            if i<len(self.ts):
                gap=self.source[self.ts[i-1].end:self.ts[i].start]
                if '/*' in gap or '//' in gap:gaps+=gap
        pointer_count=0
        while self.at(i,'*'):
            pointer_count+=1;i+=1
            if i<len(self.ts):
                gap=self.source[self.ts[i-1].end:self.ts[i].start]
                if '/*' in gap or '//' in gap:gaps+=gap
        if i>=len(self.ts) or self.ts[i].kind!='identifier':return None
        first=self.ts[i].text;i+=1
        while self.at(i,'.') and i+1<len(self.ts) and self.ts[i+1].kind=='identifier':i+=2
        map_bracket=i if first=='map' and self.at(i,'[') else None
        while self.at(i,'[') or self.at(i,'*'):
            if self.at(i,'*'):i+=1;continue
            end=self.balanced(i,'[',']')
            if end is None:return None
            i=end
        if first=='interface' and self.at(i,'{') and self.at(i+1,'}'):i+=2
        # Historical Go-style maps are compound types. Group the complete map
        # before appending outer dimensions; do not silently change value rank.
        map_value=None
        if first=='map' and map_bracket is not None and not self.comma_in_bracket(map_bracket):
            map_value=self.type(i)
            if map_value is not None:i=map_value[0]
        if i<=start:return None
        # Preserve exact base spelling and normalize any nested type arguments.
        base_start=start
        for _ in dimensions:base_start=self.dimension(base_start)[0]
        base_start+=pointer_count
        base_end=(map_value[1] if map_value is not None else self.ts[i-1].end)
        base=self.source[self.ts[base_start].start:base_end]
        base=normalize(base) if dimensions or pointer_count else base
        if map_value is not None and dimensions:base='('+base+')'

        text=gaps+base+'*'*pointer_count+''.join(reversed(dimensions))
        return i,self.ts[i-1].end,text
    def replacements(self):
        replacements=[];i=0
        while i<len(self.ts):
            token=self.ts[i]
            if token.text=='map' and self.at(i+1,'[') and i+6<len(self.ts) and self.ts[i+2].text in PRIMITIVES and self.at(i+3,'[') and self.at(i+4,']') and self.ts[i+5].text in PRIMITIVES and self.at(i+6,']'):
                replacements.append((token.start,self.ts[i+6].end,'(map['+self.ts[i+2].text+']'+self.ts[i+5].text+')[]'));i+=7;continue
            if token.text=='return' and self.at(i+1,'[') and self.at(i+2,']') and i+3<len(self.ts) and self.ts[i+3].text in PRIMITIVES:
                replacements.append((token.end,self.ts[i+3].end,' '+self.ts[i+3].text+'[]'));i+=4;continue
            if token.text=='if' and self.at(i+1,'[') and self.at(i+2,']'):
                replacements.append((self.ts[i+1].start,self.ts[i+2].end,''));i+=3;continue
            if token.kind=='identifier' and self.at(i+1,'[') and self.at(i+2,']') and i+3<len(self.ts):
                tail=self.ts[i+3]
                joined=token.text+tail.text
                if tail.kind=='identifier' and tail.text in PRIMITIVES and token.text not in PRIMITIVES and token.text not in ('return','if','else') and self.ts[i+2].end<tail.start:
                    replacements.append((token.start,tail.end,tail.text+'[] '+token.text));i+=4;continue
                if tail.kind=='identifier' and joined in self.declared_types and token.end==self.ts[i+1].start and self.ts[i+2].end==tail.start:
                    replacements.append((token.start,tail.end,joined+'[]'));i+=4;continue
            if token.text=='func' and i+2<len(self.ts) and self.ts[i+1].kind=='identifier' and self.dimension(i+2) is not None:
                parsed=self.type(i+2)
                if parsed is not None:
                    j,end,text=parsed;replacements.append((self.ts[i+1].end,end,'('+text));i=j;continue
            # Repair an old bulk replacement artefact: floatmake([][], n).
            match=re.fullmatch(r'(float|int|string|bool|f32|f64|i32|i64)make',token.text)
            if match and self.at(i+1,'('):
                j=i+2;rank=0
                while self.at(j,'[') and self.at(j+1,']'):rank+=1;j+=2
                if rank and self.at(j,','):
                    replacements.append((token.start,self.ts[j-1].end,'make('+match[1]+'[]'*rank));i=j;continue
            dimension=self.dimension(i)
            if dimension is not None:
                # A nonempty bracket following a value belongs to indexing or
                # a generic/map argument, not a prefix array declaration.
                fixed=not self.at(i+1,']')
                previous=self.ts[i-1] if i else None
                attached=False
                if previous is not None:
                    attached=previous.end==token.start and (previous.kind in ('identifier','number') or previous.text in (']',')','}'))
                    if previous.text==']' and attached:
                        depth=1;k=i-2
                        while k>=0:
                            if self.at(k,']'):depth+=1
                            elif self.at(k,'['):
                                depth-=1
                                if depth==0:break
                            k-=1
                        if k>0 and self.ts[k-1].text=='map' and not self.comma_in_bracket(k):attached=False
                    if previous.text=='*' and previous.end==token.start:
                        k=i-2
                        while k>=0 and self.ts[k].text=='*':k-=1
                        attached=k>=0 and (self.ts[k].kind=='identifier' or self.ts[k].text==']') and self.ts[k].end==self.ts[k+1].start
                blocked=attached
                if previous is not None and previous.text in PRIMITIVES and '\n' not in self.source[previous.end:token.start]:
                    blocked=attached or self.ts[dimension[0]].text not in PRIMITIVES if dimension[0]<len(self.ts) else True
                if fixed and previous is not None and '\n' not in self.source[previous.end:token.start] and (previous.kind in ('identifier','number') or previous.text in (']',')')) and previous.text not in ('return','range','case'):blocked=True
                parsed=None if blocked else self.type(i)
                if parsed is not None:
                    j,end,text=parsed
                    if '\n' not in self.source[token.start:self.ts[dimension[0]-1].end] and text!=self.source[token.start:end]:
                        replacements.append((token.start,end,text));i=j;continue
            i+=1
        return replacements

def normalize(source):
    edits=Normalizer(source).replacements()
    for start,end,text in reversed(edits):source=source[:start]+text+source[end:]
    return source

def project_sources(root):
    result=subprocess.run(['git','ls-files','-z','--cached','--others','--exclude-standard','--','*.s'],cwd=root,capture_output=True,check=True)
    for name in sorted(set(result.stdout.decode().split('\0'))):
        if not name or name.startswith(('artifact/','artifacts/')):continue
        path=root/name
        if path.is_file() and not path.is_symlink():yield path

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--write',action='store_true');ap.add_argument('--report',type=Path);args=ap.parse_args()
    root=Path(__file__).resolve().parents[1];changes=[];scanned=0
    for path in project_sources(root):
        scanned+=1;old=path.read_text();new=normalize(old)
        if old!=new:
            edits=Normalizer(old).replacements();changes.append(dict(path=str(path.relative_to(root)),edits=len(edits),lines=[old.count('\n',0,a)+1 for a,_,_ in edits]))
            if args.write:path.write_text(new)
    report=dict(scanned=scanned,changed_files=len(changes),changes=changes,mode='write' if args.write else 'check')
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(f"S array syntax: scanned={scanned} {'changed' if args.write else 'noncanonical'}={len(changes)}")
    if changes and not args.write:
        for row in changes[:15]:print(row['path']+': '+str(row['edits'])+' edits')
    return 0 if args.write or not changes else 1
if __name__=='__main__':raise SystemExit(main())

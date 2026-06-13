import os
import re
import json
import glob

TARGET_DIRS = ['lib/screens', 'lib/widgets']
JA_ARB_PATH = 'lib/l10n/app_ja.arb'
EN_ARB_PATH = 'lib/l10n/app_en.arb'

ja_pattern = re.compile(r'[\u3040-\u309f\u30a0-\u30ff\u4e00-\u9fff]+')

# $ を含まないシングル/ダブルクォート文字列
string_pattern = re.compile(r"('([^'\$]*)'|\"([^\"\$]*)\")")

def load_arb(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_arb(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def main():
    ja_arb = load_arb(JA_ARB_PATH)
    en_arb = load_arb(EN_ARB_PATH)
    
    auto_key_counter = 1
    existing_texts = {v: k for k, v in ja_arb.items() if not k.startswith('@@')}
    
    import_statement = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
    
    files_to_process = []
    for d in TARGET_DIRS:
        files_to_process.extend(glob.glob(f'{d}/**/*.dart', recursive=True))
    
    for filepath in files_to_process:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified = False
        new_content = content
        
        # const Text('日本語') -> Text('日本語') に置換 (これだけでは不足するが最初の緩和策)
        new_content = re.sub(r"const\s+Text\s*\(\s*('([^'\$]*)'|\"([^\"\$]*)\")", r"Text(\1", new_content)
        
        def replacer(match):
            nonlocal auto_key_counter, modified, ja_arb, en_arb, existing_texts
            full_match = match.group(0)
            inner_text = match.group(2) if match.group(2) is not None else match.group(3)
            
            if '$' in full_match:
                return full_match
                
            if ja_pattern.search(inner_text):
                if inner_text in existing_texts:
                    key = existing_texts[inner_text]
                else:
                    key = f"auto_msg_{auto_key_counter:03d}"
                    auto_key_counter += 1
                    ja_arb[key] = inner_text
                    en_arb[key] = inner_text
                    existing_texts[inner_text] = key
                
                modified = True
                return f"AppLocalizations.of(context)!.{key}"
            
            return full_match

        new_content = string_pattern.sub(replacer, new_content)
        
        if modified:
            if import_statement not in new_content:
                lines = new_content.split('\n')
                last_import_idx = -1
                for i, line in enumerate(lines):
                    if line.startswith('import '):
                        last_import_idx = i
                if last_import_idx != -1:
                    lines.insert(last_import_idx + 1, import_statement)
                else:
                    lines.insert(0, import_statement)
                new_content = '\n'.join(lines)
                
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated: {filepath}")

    save_arb(JA_ARB_PATH, ja_arb)
    save_arb(EN_ARB_PATH, en_arb)
    print("Done.")

if __name__ == '__main__':
    main()

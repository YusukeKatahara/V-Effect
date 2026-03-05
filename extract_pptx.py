import zipfile
import re

def extract_text(pptx_path):
    try:
        with zipfile.ZipFile(pptx_path, 'r') as z:
            slides = [f for f in z.namelist() if f.startswith('ppt/slides/slide') and f.endswith('.xml')]
            # Sort slides by number if possible
            slides.sort(key=lambda x: int(re.search(r'slide(\d+)\.xml', x).group(1)) if re.search(r'slide(\d+)\.xml', x) else 0)
            
            for filename in slides:
                content = z.read(filename).decode('utf-8')
                text_nodes = re.findall(r'<a:t>( *.*? *)</a:t>', content)
                if text_nodes:
                    print(f"--- {filename} ---")
                    for t in text_nodes:
                        print(t)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    extract_text('MVP_plan.pptx')

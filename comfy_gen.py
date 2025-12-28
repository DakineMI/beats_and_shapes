import json
import urllib.request
import time

def queue_prompt(prompt):
    p = {"prompt": prompt}
    data = json.dumps(p).encode('utf-8')
    req = urllib.request.Request("http://127.0.0.1:8000/prompt", data=data)
    with urllib.request.urlopen(req) as f:
        return json.loads(f.read().decode('utf-8'))

def check_status(prompt_id):
    with urllib.request.urlopen(f"http://127.0.0.1:8000/history/{prompt_id}") as f:
        return json.loads(f.read().decode('utf-8'))

workflow = {
    "1": {
        "inputs": {
            "model": "wan2.5-t2v-preview",
            "prompt": "Minimalist game studio logo splash, 16:9 at 480p. The entire frame is solid black. In the center, a wide, single-line logo with the word BadMadBrax is shown. Directly beneath it, a thin rectangular outline with the same width acts like an underline and contains the smaller, squat and slightly elongated word GAMES. Both are centered and fill most of the horizontal space. All letters are solid neon colors in vibrant cyan and molten pink, with some letter edges and curves shaped like circular saw blades. There are no extra visible shapes such as triangles or squares inside the letters. The logo gently pulses in brightness and slightly scales in and out in time with a quiet, distant EDM beat, moving smoothly. The camera stays almost perfectly still, with only tiny micro-movements.",
            "size": "480p: 16:9 (832x480)",
            "duration": 5,
            "seed": 42,
            "prompt_extend": True
        },
        "class_type": "WanTextToVideoApi"
    },
    "2": {
        "inputs": {
            "video": ["1", 0],
            "filename_prefix": "splash_gen",
            "format": "mp4",
            "codec": "h264"
        },
        "class_type": "SaveVideo"
    }
}

try:
    print("Queuing generation...")
    result = queue_prompt(workflow)
    prompt_id = result['prompt_id']
    print(f"Prompt queued! ID: {prompt_id}")
    
    print("Waiting for completion (this may take a few minutes)...")
    while True:
        history = check_status(prompt_id)
        if prompt_id in history:
            print("Generation complete!")
            outputs = history[prompt_id]['outputs']
            for node_id in outputs:
                if 'videos' in outputs[node_id]:
                    for video in outputs[node_id]['videos']:
                        print(f"Video saved as: {video['filename']}")
            break
        time.sleep(5)
except Exception as e:
    print(f"Error: {e}")

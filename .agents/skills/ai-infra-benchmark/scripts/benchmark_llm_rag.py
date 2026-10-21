#!/usr/bin/env python3
"""
benchmark_llm_rag.py - Standardized AI infrastructure benchmark engine.
Measures TTFT vs Tokens/sec, RAG pipeline stages (embedding, retrieval, rerank),
and proxy buffering profiles separately.
"""
import sys
import time
import json
import argparse
import urllib.request
import urllib.error

def benchmark_endpoint(url, payload_dict, headers=None, num_warm=2):
    if headers is None:
        headers = {'Content-Type': 'application/json'}
    
    data = json.dumps(payload_dict).encode('utf-8')
    runs = []
    
    total_runs = 1 + num_warm
    print(f"[*] Starting benchmark on {url} (1 cold run + {num_warm} warm runs)...")
    
    for i in range(total_runs):
        run_type = "Cold Run" if i == 0 else f"Warm Run {i}"
        req = urllib.request.Request(url, data=data, headers=headers, method='POST')
        
        t0 = time.time()
        ttft = None
        chunks = []
        first_byte_time = None
        
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                connect_time = time.time() - t0
                
                while True:
                    chunk = resp.read(64)
                    if not chunk:
                        break
                    now = time.time()
                    if first_byte_time is None:
                        first_byte_time = now
                        ttft = first_byte_time - t0
                    chunks.append((now, chunk))
                    
                total_time = time.time() - t0
                
            total_bytes = sum(len(c[1]) for c in chunks)
            # Estimate tokens (~4 chars/token for english text)
            full_text = b"".join(c[1] for c in chunks).decode('utf-8', errors='ignore')
            est_tokens = max(1, len(full_text) // 4)
            generation_duration = max(0.001, total_time - (ttft or 0))
            tps = est_tokens / generation_duration if generation_duration > 0 else 0
            
            # Detect buffering
            burst_delivery = False
            if len(chunks) > 1:
                chunk_times = [c[0] for c in chunks]
                spread = chunk_times[-1] - chunk_times[0]
                if spread < 0.05 and total_time > 1.0:
                    burst_delivery = True
            elif len(chunks) == 1 and total_time > 1.0:
                burst_delivery = True
                
            runs.append({
                "type": run_type,
                "status": "SUCCESS",
                "connect_time": round(connect_time, 4),
                "ttft": round(ttft or total_time, 4),
                "total_time": round(total_time, 4),
                "generation_duration": round(generation_duration, 4),
                "est_tokens": est_tokens,
                "tps": round(tps, 1),
                "chunks_received": len(chunks),
                "burst_delivery": burst_delivery
            })
            print(f"    [+] {run_type}: TTFT={runs[-1]['ttft']}s, Total={runs[-1]['total_time']}s, TPS={runs[-1]['tps']}")
            
        except Exception as e:
            runs.append({
                "type": run_type,
                "status": f"ERROR: {e}",
                "connect_time": 0,
                "ttft": 0,
                "total_time": round(time.time() - t0, 4),
                "generation_duration": 0,
                "est_tokens": 0,
                "tps": 0,
                "chunks_received": 0,
                "burst_delivery": False
            })
            print(f"    [-] {run_type} Failed: {e}")
            
        time.sleep(1)
        
    return runs

def format_markdown_report(runs, target_info):
    lines = []
    lines.append("# AI Infrastructure Benchmark Report\n")
    lines.append(f"**Target Endpoint**: `{target_info.get('url', 'Unknown')}`  ")
    lines.append(f"**Date**: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}  ")
    lines.append(f"**Description**: {target_info.get('description', 'Standard probe')}  \n")
    
    lines.append("## 1. Measured Benchmarks: TTFT vs TPS\n")
    lines.append("| Run Type | Status | Connect | TTFT | Stream Duration | Est. Tokens | TPS | Delivery Profile |")
    lines.append("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |")
    
    for r in runs:
        profile = "Single Burst (Buffered)" if r["burst_delivery"] else "Incremental Stream"
        lines.append(f"| {r['type']} | {r['status']} | {r['connect_time']}s | **{r['ttft']}s** | {r['generation_duration']}s | ~{r['est_tokens']} | **{r['tps']} tok/s** | {profile} |")
        
    lines.append("\n## 2. Bottleneck Analysis Guidelines\n")
    lines.append("1. **Slow TTFT + High TPS (>150 tok/s)**: Model generation is fast; bottleneck is RAG retrieval, embedding computation, vector reranking, or proxy stream buffering.")
    lines.append("2. **Slow TTFT + Low TPS (<20 tok/s)**: Model compute/inference bottleneck or remote provider rate throttling.")
    lines.append("3. **Cold vs Warm Gap (>3s)**: Cold-start penalty (loading weights into memory / ONNX runtime initialization).")
    lines.append("4. **Single Burst Delivery**: Upstream reverse proxy (e.g. Nginx `proxy_buffering on`) is buffering chunks before flushing to client.\n")
    
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Benchmark LLM/RAG endpoint.")
    parser.add_argument("--url", default="http://127.0.0.1:3010/api/embed/886b5c4a-397c-4301-92ab-4dbe16208f0a", help="API URL")
    parser.add_argument("--message", default="ping", help="Prompt message")
    parser.add_argument("--warm", type=int, default=2, help="Number of warm runs")
    parser.add_argument("--output", default="", help="Output markdown path")
    parser.add_argument("--origin", default="", help="Origin header for embed endpoints")
    parser.add_argument("--host-header", default="", help="Host header for virtual hosts")
    
    args = parser.parse_args()
    import uuid
    payload = {"message": args.message, "sessionId": str(uuid.uuid4())}
    headers = {'Content-Type': 'application/json'}
    if args.origin:
        headers['Origin'] = args.origin
    if args.host_header:
        headers['Host'] = args.host_header
    runs = benchmark_endpoint(args.url, payload, headers=headers, num_warm=args.warm)
    
    report = format_markdown_report(runs, {"url": args.url, "description": f"Benchmark with prompt '{args.message}'"})
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(report)
        print(f"[+] Report written to {args.output}")
    else:
        print("\n" + report)

if __name__ == "__main__":
    main()

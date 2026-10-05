#!/bin/bash
cd /root/agent-work/deightonllm-firstmate || exit 1
exec mcode exec --permission full --cwd /root/agent-work/deightonllm-firstmate "$(cat /tmp/firstmate-brief.txt)"

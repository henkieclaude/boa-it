#!/bin/bash
cd "$(dirname "$0")"
open -a "Google Chrome" "http://localhost:8080/"
python3 -m http.server 8080

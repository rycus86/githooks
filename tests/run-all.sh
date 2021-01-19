#!/bin/sh
find tests/ -name 'test-*.sh' -print0 | xargs -0 -n 1 -P 4 -- sh

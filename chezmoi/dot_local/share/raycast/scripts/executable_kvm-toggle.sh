#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title KVM 切替
# @raycast.mode compact
# @raycast.icon 🔀
# @raycast.packageName モニター KVM
# @raycast.description Dell U4025QW の USB 接続先を切り替える（この Mac から渡すとキーボードは効かなくなる）

exec "$HOME/.local/bin/kvm" usb toggle

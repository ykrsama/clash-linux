#!/usr/bin/bash

curpwd=$(pwd)
mypath=$(dirname $(realpath $0))

function install() {
    # Download subscription
    echo -e "\033[33mGetting config\033[0m"
    COMMAND="${mypath}/scripts/update_config.sh"
    ${COMMAND}

    # Schedule update config every hour
    echo -e "\033[33mScheduling config subscription\033[0m"
    SCHEDULE="0 * * * *"  # Every hour as an example
    CRON_JOB="$SCHEDULE $COMMAND"
    if crontab -l 2>/dev/null | grep -qF "$COMMAND"; then
        echo "The cron job already exists (≧▽≦)"
    else
        # Add the new cron job
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "New cron job added \(=^-ω-^=)/"
    fi

    # Install the clash service
    echo -e "\033[33mInstalling clash service\033[0m"
    mkdir -p $HOME/.config/systemd/user
    mkdir -p $HOME/.cache/clash/log

    cat>$HOME/.config/systemd/user/clash.service<<EOF
[Unit]
Description=Clash Service
After=network.target

[Service]
ExecStart=${clash}
Restart=always
WorkingDirectory=${mypath}
StandardOutput=append:${HOME}/.cache/clash/log/service.log
StandardError=append:${HOME}/.cache/clash/log/service.err
EOF

    systemctl --user daemon-reload
}

function ctl_clash() {
    if [[ $1 == "start" || $1 == "restart" ]]; then
        if [[ ! -f "$HOME/.config/systemd/user/clash.service" ]]; then
            install
        fi
    fi
    systemctl --user $1 clash
    state=$(systemctl --user is-active clash)
    echo -e "\033[32mClash service is \033[1m${state}\033[0m"
}

function uninstall() {
    echo -e "\033[33mUninstalling service\033[0m"
    ctl_clash "stop"
    rm $HOME/.config/systemd/user/clash.service
    systemctl --user daemon-reload
    echo -e "\n\033[33mTodo: remove crontab job:\n$ crontab -e\033[0m"
}

cd $mypath

source scripts/get_cpu_arch.sh &> /dev/null

if [[ -z "$CpuArch" ]]; then
    echo "\033[32mFailed to get CPU architecture\033[0m"
    exit 1
fi

if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64"  ]]; then
    clash=$mypath/bin/clash-linux-amd64
elif [[ $CpuArch =~ "aarch64" ||  $CpuArch =~ "arm64" ]]; then
    clash=$mypath/bin/clash-linux-arm64
elif [[ $CpuArch =~ "armv7" ]]; then
    clash=$mypath/bin/clash-linux-armv7
else
    echo -e "\033[31m\n[ERROR] Unsupported CPU Architecture ${CpuArch} >< \033[0m"
    exit 1
fi


if [[ $1 == "install" ]]; then
    install
elif [[ $1 == "uninstall" ]]; then
    uninstall
elif [[ $1 == "start" ]]; then
    ctl_clash "start"
elif [[ $1 == "stop" ]]; then
    ctl_clash "stop"
elif [[ $1 == "restart" ]]; then
    ctl_clash "restart"
elif [[ $1 == "status" ]]; then
    ctl_clash "status"
else
    echo -e "\033[33mUsage: $0 [start|stop|restart|status|install|uninstall]\033[0m"
fi

cd $curpwd

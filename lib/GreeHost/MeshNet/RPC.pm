package GreeHost::MeshNet::RPC;
use warnings;
use strict;
use IPC::Run3;

my $service_file = <<'EOF';
[Unit]
Description=nebula
Wants=basic.target
After=basic.target network.target

[Service]
SyslogIdentifier=nebula
StandardOutput=syslog
StandardError=syslog
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/sbin/nebula -config /etc/nebula/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sub install_nebula {
    run3([qw( curl -LO https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-amd64.tar.gz )]);
    run3([qw( tar -C /usr/local/sbin -xzf nebula-linux-amd64.tar.gz )]);
    unlink 'nebula-linux-amd64.tar.gz';
}

sub start_and_enable_nebula_service {
    open my $sf, ">", "/etc/systemd/system/nebula.service"
        or die "Failed to open for writing: $!";
    print $sf $service_file;
    close $sf;

    run3([qw( systemctl enable nebula )]);
    run3([qw( systemctl start nebula  )]);
}

1;

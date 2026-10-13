enum NodeExporterSample {
  static let withoutDRM = #"""
    # HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
    # TYPE node_cpu_seconds_total counter
    node_cpu_seconds_total{cpu="0",mode="idle"} 8000
    node_cpu_seconds_total{cpu="0",mode="iowait"} 100
    node_cpu_seconds_total{cpu="0",mode="irq"} 0
    node_cpu_seconds_total{cpu="0",mode="nice"} 50
    node_cpu_seconds_total{cpu="0",mode="softirq"} 25
    node_cpu_seconds_total{cpu="0",mode="steal"} 0
    node_cpu_seconds_total{cpu="0",mode="system"} 1000
    node_cpu_seconds_total{cpu="0",mode="user"} 3000
    node_cpu_seconds_total{cpu="1",mode="idle"} 7000
    node_cpu_seconds_total{cpu="1",mode="iowait"} 200
    node_cpu_seconds_total{cpu="1",mode="irq"} 5
    node_cpu_seconds_total{cpu="1",mode="nice"} 0
    node_cpu_seconds_total{cpu="1",mode="softirq"} 25
    node_cpu_seconds_total{cpu="1",mode="steal"} 10
    node_cpu_seconds_total{cpu="1",mode="system"} 1000
    node_cpu_seconds_total{cpu="1",mode="user"} 3000
    # HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.
    # TYPE node_memory_MemTotal_bytes gauge
    node_memory_MemTotal_bytes 8000000000
    node_memory_MemAvailable_bytes 2000000000
    node_memory_SwapTotal_bytes 2000000000
    node_memory_SwapFree_bytes 500000000
    # HELP node_load1 1m load average.
    # TYPE node_load1 gauge
    node_load1 3.2
    node_load5 2.8
    node_load15 2.1
    node_boot_time_seconds 1759913600
    node_time_seconds 1760000000.5
    node_filesystem_avail_bytes{device="/dev/sda1",fstype="vfat",mountpoint="/boot"} 300000000
    node_filesystem_avail_bytes{device="/dev/sda2",fstype="ext4",mountpoint="/"} 50000000000
    node_filesystem_size_bytes{device="/dev/sda1",fstype="vfat",mountpoint="/boot"} 500000000
    node_filesystem_size_bytes{device="/dev/sda2",fstype="ext4",mountpoint="/"} 100000000000
    node_network_receive_bytes_total{device="br-abc"} 600
    node_network_receive_bytes_total{device="docker0"} 700
    node_network_receive_bytes_total{device="enp5s0"} 200
    node_network_receive_bytes_total{device="eth0"} 100
    node_network_receive_bytes_total{device="lo"} 900
    node_network_receive_bytes_total{device="veth123"} 800
    node_network_receive_bytes_total{device="virbr0"} 500
    node_network_transmit_bytes_total{device="br-abc"} 60
    node_network_transmit_bytes_total{device="docker0"} 70
    node_network_transmit_bytes_total{device="enp5s0"} 20
    node_network_transmit_bytes_total{device="eth0"} 10
    node_network_transmit_bytes_total{device="lo"} 90
    node_network_transmit_bytes_total{device="veth123"} 80
    node_network_transmit_bytes_total{device="virbr0"} 50
    """#

  static let drmLines = #"""
    node_drm_gpu_busy_percent{card="card0"} 42
    node_drm_gpu_busy_percent{card="card1"} 91
    node_drm_memory_gtt_size_bytes{card="card0"} 16000000000
    node_drm_memory_gtt_size_bytes{card="card1"} 16000000000
    node_drm_memory_gtt_used_bytes{card="card0"} 200000000
    node_drm_memory_gtt_used_bytes{card="card1"} 300000000
    node_drm_memory_vram_size_bytes{card="card0"} 8000000000
    node_drm_memory_vram_size_bytes{card="card1"} 8000000000
    node_drm_memory_vram_used_bytes{card="card0"} 4000000000
    node_drm_memory_vram_used_bytes{card="card1"} 6000000000
    """#

  static let withDRM = withoutDRM + "\n" + drmLines
}

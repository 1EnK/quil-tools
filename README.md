# Quil Claim Tool v2.0.2.3

Search all .config under a directory and execute qclient commands including mint, collect, merge coins, and check total balance.

## Installation

### Download the Script

Download the `quil_batch_claim.sh` script to your server.

### Make the Script Executable

Navigate to the directory where the script is located and run:

```bash
chmod +x quil_batch_claim.sh
```

## Usage

Run the script with the required `--path` argument, specifying the directory containing your QUIL `.config`:

```bash
./quil_batch_claim.sh --path /path/to/your/configs
```

### Optional Arguments:

- `--qclient-path`: Path to the qclient executable (default: `$HOME/ceremonyclient/client/qclient-2.0.2.3-linux-amd64`), update as needed for future node upgrades
- `--max-parallel`: Maximum number of parallel processes (default: 3)

---

# quil-manager (Archived)

Deployment & management script for Quilibrium v1.4.19

## Table of Contents

- [Quil Claim Tool v2.0.2.3](#quil-claim-tool-v2023)
  - [Installation](#installation)
    - [Download the Script](#download-the-script)
    - [Make the Script Executable](#make-the-script-executable)
  - [Usage](#usage)
    - [Optional Arguments:](#optional-arguments)
- [quil-manager (Archived)](#quil-manager-archived)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation-1)
  - [Usage](#usage-1)
  - [Options \& Features](#options--features)

## Installation

1.  Download the `.sh` script file to the server.

2.  Under the directory where the script is located, run the following command to give the script execution permission.

```shell
chmod +x quil-manager.sh
```

## Usage

1.  Run the script with the following command.

```shell
./quil-manager.sh
```

2.  Select the options following the below steps:
    - Select `1` to Deploy Quilibrium Node (Only run once). Then run `source ~/.bashrc` to apply the changes.
    - (**Compulsory**) Upgrade the Quilibrium Node with `option 11` to 1.4.19.
    - Select `2` to verify the configurations and settings. Compare the output with the expected output in the [Options & Features](#options--features) section.
    - (Optional) Select `4` to Install qclient and grpcurl
    - Select `5` to start the Quilibrium Node and run for the first time to generate the .config folder.
    - (Optional) Select `3` to Modify the config.yml file.
    - (Optional) Reboot the server to apply the ufw changes with 'sudo reboot', then run the script to start the Quilibrium Node with `option 5`.
    - (Optional) Backup the Quilibrium Node when `keys.yml` is fully generated (no longer showing `null`) with `option 10`.
    - (Optional) Limit the CPU usage with `option 12`.

## Options & Features

1.  **Deploy Node**: Deploy Quilibrium Node for new servers or re-deploy Quilibrium Node for existing servers. (Recommended to run only once)

2.  **Verify Configurations**: Verify the ufw settings and node configuration file. The output should show the following if the node is properly configured.

    Current UFW status:

    ```
    Status: active

    To                         Action      From
    --                         ------      ----
    22                         ALLOW       Anywhere
    8336                       ALLOW       Anywhere
    443                        ALLOW       Anywhere
    22 (v6)                    ALLOW       Anywhere (v6)
    8336 (v6)                  ALLOW       Anywhere (v6)
    443 (v6)                   ALLOW       Anywhere (v6)
    ```

    Current go version:

    ```
    go version go1.20.14 linux/amd64
    ```

    Current network settings:

    ```
    net.core.rmem_max = 600000000
    net.core.wmem_max = 600000000
    ```

    Current config.yml settings:

    ```
    listenGrpcMultiaddr: /ip4/127.0.0.1/tcp/8337
    statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"
    ```

    Current service configuration:

    ```
    [Unit]
    Description=Ceremony Client Go App Service
    [Service]
    Type=simple
    Restart=always
    RestartSec=5s
    WorkingDirectory=/root/ceremonyclient/node
    Environment=GOEXPERIMENT=arenas
    ExecStart=/root/ceremonyclient/node/node-1.4.19-linux-amd64
    [Install]
    WantedBy=multi-user.target
    ```

    Current qclient and grpcurl installation status:

    ```
    grpcurl  qclient
    ```

3.  **Modify config.yml**: After running the node for the first time, the config.yml file will be generated. This option will modify the `listenGrpcMultiaddr` and `statsMultiaddr` settings in the config.yml file to enable the GRPC.

4.  **Install qclient and grpcurl**: Install qclient and grpcurl for the Quilibrium Node.

5.  **Start Node**: Start the Quilibrium Node service.

6.  **Stop Node**: Stop the Quilibrium Node service.

7.  **View logs**: Display real-time logs of the Quilibrium Node. Press `Ctrl + C` to exit the log.

8.  **View Node status(GRPC)**: Display the status of the Quilibrium Node using GRPC. Install the `grpcurl` and modify the config.yml file before using this option.

9.  **Check Rewards**: Check the rewards earned after 1.4.19.

10. **Backup Node keys**: Create a backup of the `config.yml` and `keys.yml`. A scp command will be generated for you to copy the backup file to your local machine.

11. **Upgrade Node**: Update the Quilibrium Node to the latest version.

12. **Limit the CPU usage**: Enter `0-100` to limit the CPU usage of the Quilibrium Node to certain percentage. VPS providers may suspend the server if the CPU usage is too high.

# ================================================================
# CompileBench Wrapper for simple-openhands
# ================================================================
# This Dockerfile extends the simple-openhands image with shell-harness
# to make it compatible with CompileBench testing framework.
#
# Prerequisites:
# 1. Build and push your simple-openhands image:
#    cd simple_openhands/
#    docker build -t <your-registry>/simple-openhands:latest .
#    docker push <your-registry>/simple-openhands:latest
#
# 2. Update the FROM line below with your image name
# ================================================================

# Base image - using remote registry
# Image pushed from: shx815666/simple-openhands:latest
FROM simple-openhands:latest

# CompileBench standard environment settings
ENV DEBIAN_FRONTEND=noninteractive \
    WORK_DIR=/home/peter \
    USERNAME=peter
SHELL ["/bin/bash", "-lc"]

# Become root to modify system-wide shell profiles
USER root

# Reset login shell PATH to system defaults (align with ubuntu-22.04-amd64)
RUN printf "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n" >> /etc/profile && \
    printf "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n" > /home/peter/.bash_profile && \
    chown peter:peter /home/peter/.bash_profile

# Ensure non-interactive bash shells (bash -c) use system PATH and unified locale
RUN printf "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\nexport LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n" > /etc/compilebench_bash_env
ENV BASH_ENV=/etc/compilebench_bash_env

# Remove any global ld.so injection of /home/peter/result/lib and refresh cache
RUN rm -f /etc/ld.so.conf.d/compilebench.conf && ldconfig

# Provide helper scripts for clean compile environments and explicit result prefix
RUN cat > /usr/local/bin/compilebench-env.sh <<'EOF' && chmod +x /usr/local/bin/compilebench-env.sh
#!/usr/bin/env bash
# Minimal environment for reproducible compile steps
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
EOF

RUN cat > /usr/local/bin/use-result-prefix.sh <<'EOF' && chmod +x /usr/local/bin/use-result-prefix.sh
#!/usr/bin/env bash
# Source this script to prefer /home/peter/result during build/run without global ld.so injection
export CFLAGS="-I/home/peter/result/include ${CFLAGS}"
export LDFLAGS="-Wl,-rpath,/home/peter/result/lib -L/home/peter/result/lib ${LDFLAGS}"
echo "CFLAGS=$CFLAGS"
echo "LDFLAGS=$LDFLAGS"
EOF

# Set working directory for CompileBench tasks
WORKDIR /home/peter

# Switch to peter user
USER peter

# Override CMD for CompileBench HTTP API mode
# Start the Python HTTP API service (bash.py + tmux mode)
CMD ["/bin/bash", "-c", "cd /simple_openhands/code && source /etc/environment && /simple_openhands/micromamba/bin/micromamba run -n simple_openhands poetry run python -m simple_openhands.main"]
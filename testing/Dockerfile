FROM archlinux:latest

# Copy and source unified configuration
COPY ../provision/config.env /tmp/config.env
RUN source /tmp/config.env && \
    pacman -Syu --noconfirm && \
    pacman -S --noconfirm $ESSENTIAL_PACKAGES

# Create user using unified configuration
RUN source /tmp/config.env && \
    useradd -m -s "$USER_SHELL" -G "$USER_GROUPS" "$USERNAME" && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel

# Set up working directory
WORKDIR /home/developer

# Copy unified provisioning scripts
COPY ../provision/unified-setup.sh /tmp/unified-setup.sh
COPY ../provision/config.env /tmp/config.env

# Make scripts executable
RUN chmod +x /tmp/unified-setup.sh

# Set Docker environment variable
ENV RUNTIME_ENV=docker

# Switch to developer user
USER developer

CMD ["/bin/bash"]
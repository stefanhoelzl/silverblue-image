FROM quay.io/fedora/fedora-silverblue:39

COPY kernel/x86_64/kernel-*.rpm /rpms/
RUN rm \
    /rpms/kernel-modules-internal-* \
    /rpms/kernel-devel-* \
    /rpms/kernel-debuginfo-* \
    /rpms/kernel-selftests-* \
    /rpms/kernel-tools-* \
    /rpms/kernel-uki-*
RUN rpm-ostree cliwrap install-to-root / && \
    # replace kernel with custom built kernel
    rpm-ostree override replace /rpms/* && \
    rm -rf /rpms && \
    rpm-ostree cleanup -m && \
    ostree container commit

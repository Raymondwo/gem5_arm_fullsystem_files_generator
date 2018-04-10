# Copyright (C) 2017 Metempsy Technology Consulting
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Author: Pau Cabre

FROM ubuntu:16.04

RUN apt-get -y update
RUN apt-get install -y gcc make python git scons g++ python-dev zlib1g-dev m4 device-tree-compiler gcc-aarch64-linux-gnu wget xz-utils bc gcc-arm-linux-gnueabi gcc-4.8-aarch64-linux-gnu gcc-4.8-arm-linux-gnueabihf gcc-arm-linux-gnueabihf

ARG release_date
#make sure release_date is set
RUN test -n "$release_date"
RUN echo ${release_date} > /release_date.txt
RUN echo "release_date $(cat /release_date.txt)"

RUN mkdir /generated_files
RUN mkdir /generated_files/binaries
RUN mkdir /generated_files/disks
RUN mkdir /generated_files/revisions


#clone gem5
RUN git clone https://gem5.googlesource.com/public/gem5
WORKDIR gem5
RUN git rev-parse --short HEAD > /generated_files/revisions/gem5

#run the python script in gem5 to generate the binaries
RUN ./util/gen_arm_fs_files.py --make-jobs=4 --dest-dir=/tmp

RUN cp /tmp/binaries/* /generated_files/binaries
RUN cp /tmp/revisions/* /generated_files/revisions

#Get old ARM FS files
WORKDIR /
RUN mkdir /old_m5_path
WORKDIR /old_m5_path
RUN wget http://www.gem5.org/dist/current/arm/aarch-system-2014-10.tar.xz
RUN tar xJvf aarch-system-2014-10.tar.xz


#Install sfdisk 2.20 (needed by gem5img.py Newer versions have a different output format and do not recognize some parameters)
WORKDIR /
RUN mkdir /sfdisk_2.20
WORKDIR /sfdisk_2.200
RUN wget https://www.kernel.org/pub/linux/utils/util-linux/v2.20/util-linux-2.20.1.tar.gz
RUN tar xzvf util-linux-2.20.1.tar.gz
WORKDIR util-linux-2.20.1
RUN ./configure --without-ncurses
RUN make
#cp sfdisk to a directory with more preference in PATH
RUN cp fdisk/sfdisk /usr/local/sbin

RUN mkdir /mount

WORKDIR /generated_files

#This is thought to run with "docker run --privileged=true -v $PWD:/shared_vol <image_name>" in order to get the file
#For some reason we need to copy the .img files from the built docker image to the running cointainer in order to be able to mount them
CMD \
for image in aarch64-ubuntu-trusty-headless linaro-minimal-aarch64;   \
do                                                                    \
    (cp /old_m5_path/disks/$image.img disks                        && \
     /gem5/util/gem5img.py mount disks/$image.img /mount           && \
     cp binaries/m5.aarch64 /mount/sbin/m5                         && \
     /gem5/util/gem5img.py umount /mount                              \
    ) || exit 1;                                                      \
done                                                               && \
for image in aarch32-ubuntu-natty-headless linux-aarch32-ael;         \
do                                                                    \
    (cp /old_m5_path/disks/$image.img disks                        && \
     /gem5/util/gem5img.py mount disks/$image.img /mount           && \
     cp binaries/m5.aarch32 /mount/sbin/m5                         && \
     /gem5/util/gem5img.py umount /mount                              \
    ) || exit 1;                                                      \
done                                                               && \
tar cJvf ../aarch-system-$(cat /release_date.txt).tar.xz binaries disks revisions   && \
cp /aarch-system-$(cat /release_date.txt).tar.xz /shared_vol


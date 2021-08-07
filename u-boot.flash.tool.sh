#!/bin/bash
#BSD 3-Clause License
#
#Copyright (c) 2021, VielLosero
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#2. Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#3. Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


usage(){
	echo "USAGE: "
	echo "       $(basename $0) d|dump {device|image}"
	echo "       $(basename $0) e|extract {device|image} {dir_to_extract}"
	echo "       $(basename $0) i|nstall {device|image} {dir_with_files}"
	echo " "
}

SECTOR_SIZE=512
IDBLOADER_IMG_SECTOR_OFFSET=64
UBOOT_ITB_SECTOR_OFFSET=16384
TRUST_IMG_SECTOR_OFFSET=24576
IDBLOADER_IMG_SECTOR_SIZE=$(($UBOOT_ITB_SECTOR_OFFSET - $IDBLOADER_IMG_SECTOR_OFFSET))
UBOOT_ITB_SECTOR_SIZE=$((TRUST_IMG_SECTOR_OFFSET - $UBOOT_ITB_SECTOR_OFFSET))
DEVICE=$2
DIR=${3:-/tmp}

comm(){
echo "=> $1"
$1
}

_extract(){
#echo "=> dd if=${DEVICE} of=$DIR/idbloader.img  bs=${SECTOR_SIZE} count=${IDBLOADER_IMG_SECTOR_SIZE} skip=${IDBLOADER_IMG_SECTOR_OFFSET}"
comm "dd if=${DEVICE} of=$DIR/idbloader.img  bs=${SECTOR_SIZE} count=${IDBLOADER_IMG_SECTOR_SIZE} skip=${IDBLOADER_IMG_SECTOR_OFFSET}"
#echo "=> dd if=${DEVICE} of=$DIR/u-boot.itb  bs=${SECTOR_SIZE} count=${UBOOT_ITB_SECTOR_SIZE} skip=${UBOOT_ITB_SECTOR_OFFSET}"
comm "dd if=${DEVICE} of=$DIR/u-boot.itb  bs=${SECTOR_SIZE} count=${UBOOT_ITB_SECTOR_SIZE} skip=${UBOOT_ITB_SECTOR_OFFSET}"
}

_hexdump(){
IDBLOADER_IMG_OFFSET=$(( ${IDBLOADER_IMG_SECTOR_OFFSET} * ${SECTOR_SIZE} )) #decimal 
IDBLOADER_IMG_HEX_OFFSET=$( echo 0x$( echo "obase=16; ${IDBLOADER_IMG_OFFSET}" | bc ))
# Se puede usar el offset en dec o en hex --> lo pongo en hex que es el que se usa normalmente
#hexdump -C -s $IDBLOADER_IMG_OFFSET -n 100 ${DEVICE}
comm "hexdump -C -s $IDBLOADER_IMG_HEX_OFFSET -n 0x10 ${DEVICE}"

UBOOT_ITB_OFFSET=$(( ${UBOOT_ITB_SECTOR_OFFSET} * ${SECTOR_SIZE} )) #decimal 
UBOOT_ITB_HEX_OFFSET=$( echo 0x$( echo "obase=16; ${UBOOT_ITB_OFFSET}" | bc ))
# Se puede usar el offset en dec o en hex --> lo pongo en hex que es el que se usa normalmente
#hexdump -C -s $IDBLOADER_IMG_OFFSET -n 100 ${DEVICE}
comm "hexdump -C -s $UBOOT_ITB_HEX_OFFSET -n 0x10 ${DEVICE}"
}

_install(){
IDBLOADER_IMG=${DIR}/idbloader.img
UBOOT_ITB=${DIR}/u-boot.itb
[[ -e $IDBLOADER_IMG ]] && \
comm "dd if=${IDBLOADER_IMG} of=${DEVICE} seek=${IDBLOADER_IMG_SECTOR_OFFSET} status=progress" || \
echo "$IDBLOADER_IMG not found."
[[ -e $UBOOT_ITB ]] && \
comm "dd if=${UBOOT_ITB} of=${DEVICE} seek=${UBOOT_ITB_SECTOR_OFFSET} status=progress" || \
echo "$UBOOT_ITB not found."
}

case $1 in

	d|dump) _hexdump
		;;
	e|extract) _extract
		;;
	i|install) _install
		;;
	*) usage
		;;

esac

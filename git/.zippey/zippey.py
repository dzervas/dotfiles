#!/usr/bin/env python

# Downloaded from https://bitbucket.org/sippey/zippey/commits/1b1386bad389a6d5725adbeefa03acea40a43fed
#  Copyright (c) 2014, Sippey Fun Lab
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
#    * Neither the name of the Sippey Fun Lab nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER BE LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#


#
#  Zippey: A Git filter for friendly handling of ZIP-based files
#
#  There are many types of ZIP-based files, such as  Microsoft Office .docx,
#  .xlsx, .pptx files, OpenOffice .odt files and jar files, that contains
#  plaintext content but not really tractable by git due to compression smears
#  parts that have been modified and parts that remain the same across commit.
#  This prevent Git from versioning these files and treat them as a new binary
#  blob every time the file is saved.
#
#  Zippey is a Git filter that un-zip zip-based file into a simple text format
#  during git add/commit ("clean" process) and recover the original zip-based
#  file after git checkout ("smudge" process). Since diff is taken on the
#  "cleaned" file after file is added, it is likely real changes to file can be
#  reflected by original git diff command.
#
#  The text format is defined as a series of records. Each records represent a
#  file in the original zip-based file, which is composed of two parts,
#  a header that contains meta file and a body that contains data. The header
#  is a few data fields segmented by pipe character like this:
#
#       length|raw_length|type|filename
#
#  where length is an ascii coded integer of the following data section, raw_length
#  is the orginal length of data (if transformation is taken), type can be A for
#  text data or B for binary data, and filename is the original file name
#  including path if the zip-based file contains directories. Immediately after
#  the header, there is a carriage return ('\n'), follows "length" byte of
#  data, and then another CR and then the next recor, i,e,
#
#       [header1]\n[data1]\n[header2]\n[data2] ...
#
#  There are two types of data section. If the file contains only text data,
#  its content is copied to data section without any change, otherwise, data
#  is base64 coded to ensure the entire file is text format.
#
#
#  Author: Sippey (sippey@gmail.com)
#  Date: Apr.18, 2014
#
#  Modified by Kristian Hoey Horsberg <khh1990 ' at ' gmail.com>
#  to make python 3 compatible
#  Date May 20th 2014
#

import zipfile
import sys
import io
import base64
import string
import tempfile
import os.path

DEBUG_ZIPPEY = False
NAME = 'Zippey'
ENCODING = 'UTF-8'


def debug(msg):
    '''Print debug message'''
    if DEBUG_ZIPPEY:
        sys.stderr.write('{0}: debug: {1}\n'.format(NAME, msg))

def error(msg):
    '''Print error message'''
    sys.stderr.write('{0}: error: {1}\n'.format(NAME, msg))

def init():
    '''Initialize writing; set binary mode for windows'''
    debug("Running on {}".format(sys.platform))
    if sys.platform.startswith('win'):
        import msvcrt
        debug("Enable Windows binary workaround")
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
        msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)

def encode(input, output):
    '''Encode into special VCS friendly format from input to output'''
    debug("ENCODE was called")
    tfp = tempfile.TemporaryFile(mode='w+b')
    tfp.write(input.read())
    zfp = zipfile.ZipFile(tfp, "r")
    for name in zfp.namelist():
        data = zfp.read(name)
        text_extentions = ['.txt', '.html', '.xml']
        extention = os.path.splitext(name)[1][1:].strip().lower()
        try:
            # Check if text data
            data.decode(ENCODING)
            try:
                strdata = map(chr, data)
            except TypeError:
                strdata = data
            if extention not in text_extentions and not all(c in string.printable for c in strdata):
                raise UnicodeDecodeError(ENCODING, "".encode(ENCODING), 0, 1, "Artificial exception")

            # Encode
            debug("Appending text file '{}'".format(name))
            output.write("{}|{}|A|{}\n".format(len(data), len(data), name).encode(ENCODING))
            output.write(data)
            output.write("\n".encode(ENCODING)) # Separation from next meta line
        except UnicodeDecodeError:
            # Binary data
            debug("Appending binary file '{}'".format(name))
            raw_len = len(data)
            data = base64.b64encode(data)
            output.write("{}|{}|B|{}\n".format(len(data), raw_len, name).encode(ENCODING))
            output.write(data)
            output.write("\n".encode(ENCODING))  # Separation from next meta line
    zfp.close()
    tfp.close()

def decode(input, output):
    '''Decode from special VCS friendly format from input to output'''
    debug("DECODE was called")
    tfp = tempfile.TemporaryFile(mode='w+b')
    zfp = zipfile.ZipFile(tfp, "w", zipfile.ZIP_DEFLATED)

    while True:
        meta = input.readline().decode(ENCODING)
        if not meta:
            break

        (data_len, raw_len, mode, name) = [t(s) for (t, s) in zip((int, int, str, str), meta.split('|'))]
        if mode == 'A':
            debug("Appending text file '{}'".format(name))
            zfp.writestr(name.rstrip(), input.read(data_len))
            input.read(1) # Skip last '\n'
        elif mode == 'B':
            debug("Appending binary file '{}'".format(name.rstrip()))
            zfp.writestr(name.rstrip(), base64.b64decode(input.read(data_len)))
            input.read(1) # Skip last '\n'
        else:
            # Should never reach here
            zfp.close()
            tfp.close()
            error('Illegal mode "{}"'.format(mode))
            sys.exit(1)

    # Flush all writes
    zfp.close()

    # Write output
    tfp.seek(0)
    output.write(tfp.read())
    tfp.close()

def main():
    '''Main program'''
    init()

    input = io.open(sys.stdin.fileno(), 'rb')
    output = io.open(sys.stdout.fileno(), 'wb')

    if len(sys.argv) < 2 or sys.argv[1] == '-' or sys.argv[1] == '--help':
        sys.stdout.write("{}\nTo encode: 'python zippey.py e'\nTo decode: 'python zippey.py d'\nAll files read from stdin and printed to stdout\n".format(NAME))
    elif sys.argv[1] == 'e':
        encode(input, output)
    elif sys.argv[1] == 'd':
        decode(input, output)
    else:
        error("Illegal argument '{}'. Try --help for more information".format(sys.argv[1]))
        sys.exit(1)

if __name__ == '__main__':
    main()

#!/bin/sh

brr_encoder -sc8000 error.wav error.brr
brr_encoder -sc16000 write.wav write.brr
brr_encoder -sc16000 erase.wav erase.brr
brr_encoder -sc16000 click.wav click.brr
brr_encoder -sc16000 back.wav back.brr
brr_encoder -sc16000 solved.wav solved.brr

ls -lh *.brr

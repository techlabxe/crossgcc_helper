#!/usr/bin/env python

import shutil
import sys,os
import subprocess

LLVM_URL_BASE='http://llvm.org/releases/'
LLVM_VER = '3.5.0'
PREFIX = '/home/buildLLVM'

LLVM_FILE_NAME = 'llvm-%s.src.tar.xz' % LLVM_VER
CLANG_FILE_NAME = 'cfe-%s.src.tar.xz' % LLVM_VER
COMPILER_RT_FILE_NAME = 'compiler-rt-%s.src.tar.xz' % LLVM_VER

def downloadFile( url ):
	args = "wget %s" % url
	subprocess.call( args.strip().split(" "), stderr=subprocess.STDOUT )

def unpackFile( file ):
	args = 'tar xvJf %s' % file
	subprocess.call( args.strip().split(" "), stderr=subprocess.STDOUT )


def downloadLLVM():
  baseUrl = LLVM_URL_BASE + LLVM_VER + "/"
  if not os.path.exists( LLVM_FILE_NAME ) :
    url = baseUrl+LLVM_FILE_NAME
    downloadFile( url )
  if not os.path.exists( CLANG_FILE_NAME ) :
    url = baseUrl+CLANG_FILE_NAME
    downloadFile( url )
  if not os.path.exists( COMPILER_RT_FILE_NAME ) :
    url = baseUrl+COMPILER_RT_FILE_NAME
    downloadFile( url )

def shCmd(cmd):
  subprocess.call( cmd.strip().split(' '), stderr=subprocess.STDOUT )

def constructSources():
  if os.path.exists( 'llvm-%s.src' % LLVM_VER ):
    shutil.rmtree( 'llvm-%s.src' % LLVM_VER )
  unpackFile( LLVM_FILE_NAME )
  unpackFile( CLANG_FILE_NAME )
  unpackFile( COMPILER_RT_FILE_NAME )
  cmd = 'mv cfe-%s.src clang' % LLVM_VER
  shCmd( cmd )
  cmd = 'mv compiler-rt-%s.src compiler-rt' % LLVM_VER
  shCmd( cmd )
  cmd = 'mv compiler-rt llvm-%s.src/projects/compiler-rt' % LLVM_VER
  shCmd( cmd )
  cmd = 'mv clang llvm-%s.src/tools' % LLVM_VER
  shCmd( cmd )

def configureLLVM():
  if os.path.exists( 'build' ):
    shutil.rmtree( 'build' )
  cur_dir = os.getcwd()
  os.mkdir( 'build' )
  os.chdir( 'build' )
  args = '../llvm-%s.src/configure --disable-assertions --enable-optimized' % LLVM_VER
  args += ' --prefix=' + PREFIX
  args += ' --enable-targets=x86,arm,mips,x86_64'
  print "***COMMAND***"
  print args
  shCmd( args )
  os.chdir( cur_dir )

def makeLLVM():
  cur_dir = os.getcwd()
  os.chdir( 'build' )
  args = 'make -j4'
  shCmd( args )
  os.chdir( cur_dir )


downloadLLVM()
constructSources()
configureLLVM()
makeLLVM()


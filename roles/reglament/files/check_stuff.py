#!/usr/bin/env python

import sys
import os
import re
import getopt
import glob
import time
import subprocess

class Temperature:
    def findBMCSensors(self):
        cmd = subprocess.Popen("ipmitool sensor", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        if cmd.wait() != 0:
            return 1
        for row in cmd.stdout.readlines():
            if 'degrees C' in row:
                raw = row.rstrip('\n').split('|')
                label = raw[0]
                temp = raw[1].strip(' ').split('.')[0]
                if temp != 'na':
                    self.probes[label] = int(temp)
        return 0

    def findLinuxSensors(self):
        iteratorCounter = 0
        sensors = sorted(glob.glob('/sys/class/hwmon/hwmon*'))
        for sensor in sensors:
            tempFiles = glob.glob(os.path.join(sensor, 'device/temp*_input'))
            for tempFile in tempFiles:
                try:
                    tempRawFd = open(tempFile, 'r')
                    tempRaw = tempRawFd.readline().rstrip('\n')
                    temp = re.search('\d+', tempRaw).string
                except (IOError, OSError):
                    pass
                labelFile = tempFile.replace('input', 'label')
                label = 'Sensor ' + str(iteratorCounter) + ': '
                try:
                    label = label + open(labelFile, 'r').readline().rstrip('\n')
                except (IOError, OSError):
                    label = label + 'Unknown'
                self.probes[label] = int(temp) / 1000
                tempRawFd.close()
            iteratorCounter = iteratorCounter + 1

    def findFreeBSDSensors(self):
        cmd = subprocess.Popen("sysctl dev.cpu", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        for row in cmd.stdout.readlines():
            if 'temperature' in row:
                label, temp = row.split(' ')
                self.probes[label] = int(temp.split('.')[0])

    def checkProbes(self):
        for label, temp in self.probes.items():
            if temp > self.crit:
                self.critProbes[label] = temp
            elif temp > self.warn:
                self.warnProbes[label] = temp
        if not self.probes:
            return 3
        elif self.critProbes:
            return 2
        elif self.warnProbes:
            return 1
        return 0

    def __init__(self):
        self.probes = {}
        self.warnProbes = {}
        self.critProbes = {}
        self.crit = 80
        self.warn = 65

#class MegaCLI:
#    def __init__(self):

class Smart:
    def _gatherDevices(self):
        devices = sorted(glob.glob('/sys/block/sd*'))
        for device in devices:
            self.dev.append(os.path.basename(device))

    def probeHDD(self):
        cmd = subprocess.Popen("smartctl", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)

    def detectLinuxDeviceType(self):
        cmd = subprocess.Popen("lspci", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        for row in cmd.stdout:
            if 'RAID bus controller' in row:
                if 'MegaRAID' in row:
                    return 'MegaRAID'
                elif 'Areca' in row:
                    return 'Areca'
                else:
                    return 'Unsupported raid controller type: %s' % (row)
        return 'HDD'

    def __init__(self):
        self.probes = {}
        self.dev = []
        self._gatherDevices()

class Cache:
    def read(self):
        try:
            fd = open(self.cacheFile, 'r')
            output = fd.readline().rstrip('\n')
            fd.close()
        except (IOError, OSError):
            return -1
        if self.pid:
            if output.startswith('CRITICAL:'):
                print output
                return 2
            elif output.startswith('WARNING:'):
                print output
                return 1
            elif output.startswith('OK:'):
                print output
                return 0
            else:
                return -1
        else:
            return -1

    def write(self, txt):
        fd = open(self.cacheFile, 'w')
        fd.write(txt)
        fd.close()
        if self.pid:
            self.read()

    def __init__(self, cacheFile):
        self.cacheFile = cacheFile
        self.cache_expire = 300
        try:
            delta = time.time() - os.path.getmtime(self.cacheFile)
        except (IOError, OSError):
            delta = self.cache_expire
        if int(delta) >= self.cache_expire:
            self.pid = os.fork()
        try:
            self.pid
        except AttributeError:
            self.pid = os.getpid()

def checkSmart():
    smart = Smart()
    if sys.platform.startswith('linux'):
        print smart.detectLinuxDeviceType()
    elif sys.platform.startswith('freebsd'):
        print "UNKNOWN: not yet supported"
        return 3
    else:
        print "UNKNOWN: not yet supported"
        return 3

def checkTemp(cache):
    temperature = Temperature()
    temperature.findBMCSensors()
    if sys.platform.startswith('linux'):
        temperature.findLinuxSensors()
    elif sys.platform.startswith('freebsd'):
        temperature.findFreeBSDSensors()
    else:
        print "UNKNOWN: Platform %s doesn't supported" % (sys.platform)
        return 3
    rc = temperature.checkProbes()
    if rc == 3:
        if cache.pid:
            print "UNKNOWN: Couldn't find any of useful sensors"
    elif rc == 2:
        cache.write('CRITICAL: %s WARNING: %s' % (str(temperature.critProbes.items()), str(temperature.warnProbes.items())))
    elif rc == 1:
        cache.write('WARNING: %s' % (str(temperature.warnProbes.items())))
    elif rc == 0:
        cache.write('OK: %s' % (str(temperature.probes.items())))
    return rc

def main(argv=None):
    if argv is None:
        argv = sys.argv
    try:
        opts, rem = getopt.getopt(argv[1:], "hst", ["version","help","smart","temp"])
    except getopt.GetoptError as err:
        print 'UNKNOWN: %s' % (err)
        return 3
    for opt, arg in opts:
        if opt in ('--version'):
            Usage().version()
            return 0
        elif opt in ('-h', '--help'):
            Usage().help()
            return 0
        elif opt in ('-s', '--smart'):
            rc = checkSmart()
            return rc
        elif opt in ('-t', '--temp'):
            try:
                cache = Cache('/tmp/check_temp.cache')
                rc = cache.read()
                if rc == -1:
                    rc = checkTemp(cache)
            except:
                print 'UNKNOWN: unexpected error:' , sys.exc_info()[0]
                rc = 3
            return rc
    return 0

if __name__ == "__main__":
    sys.exit(main())

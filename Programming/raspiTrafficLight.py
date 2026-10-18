#!/usr/bin/python
#-*- coding: utf-8 -*-
#
# Kleines Beispielscript welches zwei Ampeln simuliert, die
# per GPIO von einer Raspberrypi gesteuert werden.
#
# Die Ampeln stehen quer zueinander, d.h. eine zeigt immer
# Rot während die andere Grün zeigt und umgekehrt.
#
# Um die zwei Ampeln zu steuern werden 6 LEDs, die an ein
# Raspberry GPIO angeschlossen sind benötigt. Zusätzlich müssen
# noch die benutzten GPIO Ports für trafficlight1 und
# trafficlight 2 angepasst werden
#
# Entstanden ist das Script um sich mal in die Python Threadings
# praktisch einzuarbeiten.
#
# Das Funktionsprinzip ist wie folgt:
#
# Eine Ampel hat ein Programm welches jeweils die einzelnen LEDs, die
# in einer Phase ein bzw aus sein müssen, definiert. Die Phasenlänge
# wird jeweils pro Phase im Programm definiert.
#
# Ein AmpelThread sort dafür, dass die Ampel regelmäßig ihre Phase weiterschalten.
#
# Die Weiterschaltung der Phasen aller Ampeln steuert ein Ampelcontroller,
# der regelmäßige Ticks an die Ampelthreads schickt damit sie die Ampeln
# weiterschalten lassen.
#
# Der Ampelcontroller initialisiert die Ampeln und lässt sie ein Initialisierungsprogramm,
# welches jede LED Kombination testet, durchlaufen. Danach schaltet er die Ampeln in den
# Auszustand, d.h. die gelbe LED blinkt. Anschliessend wird das normale Ampelprogramm
# gestartet. Dieses findet in einer Endlosschleife statt und muss durch CTRL-C beendet
# werden.
#
# Es sind 3 verschiedene Ampelprogramme definiert, die der Reihenfolge pro Ampel
# durchlaufen werden.
#
# (C) 2015 - framp at linux-tips-and-tricks dot de
#

import RPi.GPIO as GPIO
import time
import threading
import sys
import signal
import logging

VERSION="0.2.1"

GPIO.setmode(GPIO.BOARD)

# GPIO pins for red yellow green
trafficLight1=[18,22,7]			# <=== Adapt to local environment
trafficLight2=[13,15,16]		# <=== Adapt to local environment

DEBUG=False						# threading debug
Thread_CTORDTOR=False			# constructing and destructing of threads

# ticks
CONDUCTOR_TICK_TIME=.1 	# seconds

# sleep counter for LED transitions multiplied by conductor_tick_time
SLEEP_MAIN=40
SLEEP_TRANSITION=10
SLEEP_TRANSITION1=10
SLEEP_TRANSITION2=10
SLEEP_TRANSITION3=10
SLEEP_TRANSITION4=10
SLEEP_NOOP=5
SLEEP_INIT=1

# delays to display the different light states in seconds

KEEP_INITIAL=2.5
KEEP_NOOP=5
KEEP_NORMAL=30

# different trafific light programs

NORMAL_PROGRAM=[None]*3
NORMAL_PROGRAM_PHASE_RED=[None]*3
NORMAL_PROGRAM_PHASE_GREEN=[None]*3

# traffic lights shown (red, yellow, green) and the sleep time (time the current lights are on)

NORMAL_PROGRAM[0]=[
		[[1,0,0],SLEEP_MAIN],		# red
		[[1,1,0],SLEEP_TRANSITION],	# red yellow
		[[0,0,1],SLEEP_MAIN],		# green
		[[0,1,0],SLEEP_TRANSITION]	# yellow
	]
NORMAL_PROGRAM_PHASE_RED[0]=0
NORMAL_PROGRAM_PHASE_GREEN[0]=len(NORMAL_PROGRAM[0])/2

NORMAL_PROGRAM[1]=[
		[[1,0,0],SLEEP_MAIN],		# red
		[[1,0,0],SLEEP_TRANSITION1],# red
		[[1,1,0],SLEEP_TRANSITION2],# red yellow

		[[0,0,1],SLEEP_MAIN],		# green
		[[0,1,0],SLEEP_TRANSITION1],# yellow
		[[1,0,0],SLEEP_TRANSITION2] # red
	]
NORMAL_PROGRAM_PHASE_RED[1]=0
NORMAL_PROGRAM_PHASE_GREEN[1]=len(NORMAL_PROGRAM[1])/2

NORMAL_PROGRAM[2]=[
		[[1,0,0],SLEEP_MAIN],		# red
		[[1,0,0],SLEEP_TRANSITION1],# red
		[[1,0,0],SLEEP_TRANSITION2],# red
		[[1,1,0],SLEEP_TRANSITION3],# red yellow
		[[0,0,1],SLEEP_TRANSITION4],# green

		[[0,0,1],SLEEP_MAIN],		# green
		[[0,1,0],SLEEP_TRANSITION1],# yellow
		[[1,0,0],SLEEP_TRANSITION2],# red
		[[1,0,0],SLEEP_TRANSITION3],# red
		[[1,0,0],SLEEP_TRANSITION4] # red
]
NORMAL_PROGRAM_PHASE_RED[2]=0
NORMAL_PROGRAM_PHASE_GREEN[2]=len(NORMAL_PROGRAM[2])/2

# traffic light out of order
NOOP_PROGRAM=[
		[[0,1,0],SLEEP_NOOP],		# yellow
		[[0,0,0],SLEEP_NOOP]		# off
		]

# traffic light initialization, test all LEDs in all combinations
INITIALIZATION_PROGRAM_PHASE_MAIN=0
INITIALIZATION_PROGRAM_PHASE_NOTMAIN=7
INITIALIZING_PROGRAM=[
		[[1,0,0],SLEEP_INIT],
		[[0,1,0],SLEEP_INIT],
		[[0,0,1],SLEEP_INIT],
		[[0,1,0],SLEEP_INIT],
		[[1,0,0],SLEEP_INIT],
		[[0,0,0],SLEEP_INIT*2],
		[[1,1,1],SLEEP_INIT*2],
		[[0,1,1],SLEEP_INIT],
		[[1,0,1],SLEEP_INIT],
		[[1,1,0],SLEEP_INIT],
		[[1,0,1],SLEEP_INIT],
		[[0,1,1],SLEEP_INIT],
		[[0,0,0],SLEEP_INIT*2],
		[[1,1,1],SLEEP_INIT*2]
		]

# invoke cleanup at program end
def signal_handler(signal, frame):
		cleanup()
		sys.exit(0)

signal.signal(signal.SIGINT|signal.SIGHUP, signal_handler)

# cleanup all threads and GPIO
def cleanup():
	
	if Thread_CTORDTOR:
		print "*** Stopping threads ***",conductor
	conductor.stop()
	conductor.join()

	if threading.activeCount()>1:
		print "??? Threads not stopped ???"
		for t in threading.enumerate():
			print t

	if Thread_CTORDTOR:
		print "*** Cleaning up GPIO ***"
	GPIO.cleanup()

# Simple class which allows controlled stop of a thread
class StoppableThread(threading.Thread):

	def __init__(self):
		super(StoppableThread, self).__init__()
		self._stop = threading.Event()

	def stop(self):
		self._stop.set()

	def stopped(self):
		return self._stop.isSet()

####################################################################################
#
#		TrafficlightConductor
#
####################################################################################

# Conductor sends a tick to lights to synchronize their timing
class TrafficLightConductor(StoppableThread):

	def __init__(self, trafficLights):
		super(TrafficLightConductor, self).__init__()
		self.trafficLights=trafficLights
		self.trafficLightThreads=[]
		self.tickEvent=threading.Condition()

# 		create threads for lights
		for light in self.trafficLights:
			thread=TrafficLightThread(light, self.tickEvent)
			if Thread_CTORDTOR:
				print self.__class__.__name__,"Created ", thread, threading.current_thread()
			self.trafficLightThreads.append(thread)

		self.setInitialProgram()

	def run(self):

		if DEBUG:
			print self.__class__.__name__,"Running",threading.current_thread()

# 		start light threads now
		for thread in self.trafficLightThreads:
			thread.start()

#		send ticks
		while not self.stopped():
			time.sleep(CONDUCTOR_TICK_TIME)
			if DEBUG:
				print self.__class__.__name__,"Tick",threading.current_thread()
			with self.tickEvent:
				self.tickEvent.notifyAll()

#		conductor thread was stopped, now stop lightthreads
		if Thread_CTORDTOR:
			print self.__class__.__name__,"run stopping"
		for t in self.trafficLightThreads:
			if Thread_CTORDTOR:
				print self.__class__.__name__,"Stopping ", t
			t.stop()

#		and wait for their completion
		if Thread_CTORDTOR:
			print self.__class__.__name__,"Start joining of subthreads"
		for t in self.trafficLightThreads:
			if Thread_CTORDTOR:
				print self.__class__.__name__,"Joining ", t
			t.join()

	def stop(self):
			if Thread_CTORDTOR:
				print self.__class__.__name__,"Stopped", threading.current_thread()
			super(TrafficLightConductor, self).stop()

	def setInitialProgram(self):
		main=True
		for light in self.trafficLights:
			if main:
				light.setProgram(INITIALIZING_PROGRAM,INITIALIZATION_PROGRAM_PHASE_MAIN)
				main=False
			else:
				light.setProgram(INITIALIZING_PROGRAM,INITIALIZATION_PROGRAM_PHASE_NOTMAIN)
				main=True

	def setNoopProgram(self):
		for light in self.trafficLights:
			light.setProgram(NOOP_PROGRAM)

	def setNormalProgram(self,programVariant):
		main=True
		for light in self.trafficLights:
			if main:
				light.setProgram(NORMAL_PROGRAM[programVariant],NORMAL_PROGRAM_PHASE_GREEN[programVariant])
				main=False
			else:
				light.setProgram(NORMAL_PROGRAM[programVariant],NORMAL_PROGRAM_PHASE_RED[programVariant])
				main=True

####################################################################################
#
#		TrafficlightThread
#
####################################################################################

# Controls the running traffic light by handling the controller ticks
class TrafficLightThread(StoppableThread):

	def __init__(self, trafficLight, tickEvent):
		super(TrafficLightThread, self).__init__()
		self.trafficLight=trafficLight
		self.tickEvent=tickEvent

	def run(self):
		while not self.stopped():
			if DEBUG:
				print self.__class__.__name__,"Waiting for tick", threading.current_thread()
			with self.tickEvent:
				self.tickEvent.wait()
				self.trafficLight.tick()
		if Thread_CTORDTOR:
			print self.__class__.__name__,"run stopping", threading.current_thread()

	def stop(self):
			if Thread_CTORDTOR:
				print self.__class__.__name__,"Stopping", threading.current_thread()
			super(TrafficLightThread, self).stop()
			with self.tickEvent:			# revoke threads waiting for tick
				self.tickEvent.notifyAll()

####################################################################################
#
#		Trafficlight
#
####################################################################################

# a simple traffic light simulated with three LEDs
# Paramaters:
# name: just a name
# pins: a list of the three pins used by the light (red, yellow, green)
# initialPhase: the initial state of the light program running on the traffic light
# program: the light program (e.g. normal, initializing or inactive)
class TrafficLight:

	def __init__(self, name, pins, initialPhase=0, program=INITIALIZING_PROGRAM):
		self.name=name
		(self.red, self.yellow, self.green) = pins
		assert initialPhase >= 0 and initialPhase <= len(program)
		self.programChangeLock=threading.Lock()		# sync of program changes
		GPIO.setup(self.green,GPIO.OUT)
		GPIO.setup(self.yellow,GPIO.OUT)
		GPIO.setup(self.red,GPIO.OUT)
		self.setProgram(program,initialPhase)

	def setRed(self,state=True):
		GPIO.output(self.red,state)

	def setYellow(self,state=True):
		GPIO.output(self.yellow,state)

	def setGreen(self,state=True):
		GPIO.output(self.green,state)

	def setProgram(self, program, phase=0):
		with self.programChangeLock:				# sync with running phase changes
			self.program=program
			self.setPhase(phase)
			self.ticksToWait=self.program[self.phase][1]

#	set LEDs according phase
	def setPhase(self,phase):
		if DEBUG:
			print self.__class__.__name__,"Phase", threading.current_thread()
		assert phase>=0 and phase<=len(self.program)
		self.phase=phase
		self.setRed(self.program[self.phase][0][0])
		self.setYellow(self.program[self.phase][0][1])
		self.setGreen(self.program[self.phase][0][2])

#	advance to next phase modulo number of phases
	def setNextPhase(self):
		with self.programChangeLock:		# sync with program update
			self.setPhase((self.phase +1) % len(self.program))
			self.ticksToWait=self.program[self.phase][1]

#	another tick received
	def tick(self):
		self.ticksToWait=self.ticksToWait-1
		if DEBUG:
			print elf.__class__.__name__,"Got tick", threading.current_thread(),self.ticksToWait
		if self.ticksToWait == 0:
			self.setNextPhase()

####################################################################################
#
#		Main
#
####################################################################################

time.sleep(5)

#	initiate lights and conductor
light1=TrafficLight("North",trafficLight1)
light2=TrafficLight("East",trafficLight2)

conductor=TrafficLightConductor([light1,light2])

try:
#	start traffic lights to blink

	conductor.start()
	time.sleep(KEEP_INITIAL)

	while True:

		conductor.setNoopProgram()
		time.sleep(KEEP_NOOP)

		for program in range(0,len(NORMAL_PROGRAM)):
			conductor.setNormalProgram(program)
			time.sleep(KEEP_NORMAL)

			conductor.setNoopProgram()
			time.sleep(KEEP_NOOP)

		conductor.setInitialProgram()
		time.sleep(KEEP_INITIAL)

#	wait until conductor completed or interupted by CTRL-C
	conductor.join()

#	catch exception to suppress message
except KeyboardInterrupt:
	pass

#	any other exception should be printed
except Exception as ex:
	print ex

finally:
	cleanup()

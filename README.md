# The Fonz (Sega, 1976) for MiSTer

MiSTer FPGA core for SEGA's The Fonz (1976), based on the TTL schematics and one real board video recording.

This game is a clone of Man-TT (1976, confirmed by schematics) and possibly of Moto Cross (1976).

Analog acceleration is available via stick (configurable) and R trigger for compatible MiSTer mains.
Steering is digital on the original board, and controller vibration simulates its rumble solenoid.

Audio output is not available. The board relies on pre-recorded sounds played by an 8-track tape, of which no recording exists.

Original cabinet had a 4:3 screen oriented vertically by altering the monitor's internal wiring. Since the game manipulates scanlines to achieve its scaling effects, this core's analog video output conforms to a board connected to a regularly wired screen, with the intended graphics horizontally stretched. Digital video output is 3:4 by default; a 3:4 scaling option is also available for analog video output (off by default).

Game settings were adjusted by the operator relying on visual cues printed on the service manual. These are adjustable in the options: default settings are the closest approximation of the illustrated guide.

ROMs are not included, please provide your own fonz.zip conformed to MAME's romset.

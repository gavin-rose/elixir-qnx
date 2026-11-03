/*
 * Simulated QNX laboratory analyzer.
 *
 * A deliberately simple real-time sampling loop: every 500 ms it emits one
 * telemetry line on stdout. It is the "important task" and runs as a native
 * QNX process, scheduled by QNX (launched at a real-time priority via `on -p`).
 * The BEAM supervises and reads it; it does not run the real-time loop itself.
 *
 *   TELEM <seq> <reading> <temp_c> <pressure_kpa> <status>
 *
 * Fault injection and calibration are read from control files each tick, so the
 * Elixir side can inject faults and push calibration updates with no restart:
 *   /data/var/analyzer.cmd  -> one of: ok | overheat | stuck | crash
 *   /data/var/analyzer.cal  -> a floating-point calibration multiplier
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

static double read_cal(void) {
  FILE *f = fopen("/data/var/analyzer.cal", "r");
  double cal = 1.0;
  if (f) {
    if (fscanf(f, "%lf", &cal) != 1) cal = 1.0;
    fclose(f);
  }
  return cal;
}

static void read_cmd(char *buf, size_t n) {
  buf[0] = '\0';
  FILE *f = fopen("/data/var/analyzer.cmd", "r");
  if (f) {
    if (!fgets(buf, (int)n, f)) buf[0] = '\0';
    fclose(f);
  }
  char *nl = strchr(buf, '\n');
  if (nl) *nl = '\0';
}

int main(void) {
  setvbuf(stdout, NULL, _IOLBF, 0);
  unsigned long seq = 0;
  struct timespec period = {0, 500L * 1000L * 1000L};

  for (;;) {
    char cmd[64];
    read_cmd(cmd, sizeof cmd);
    double cal = read_cal();

    double t = (double)seq * 0.5;
    double reading = (50.0 + 20.0 * sin(t / 3.0)) * cal;
    double temp = 36.5 + 0.5 * sin(t / 7.0);
    double pressure = 101.3 + 1.5 * sin(t / 5.0);
    const char *status = "ok";

    if (strcmp(cmd, "overheat") == 0) {
      temp += 25.0;
      status = "overheat";
    } else if (strcmp(cmd, "stuck") == 0) {
      reading = 0.0;
      status = "stuck";
    } else if (strcmp(cmd, "crash") == 0) {
      fprintf(stderr, "analyzer: injected fault, aborting\n");
      abort();
    }

    printf("TELEM %lu %.2f %.2f %.2f %s\n", seq, reading, temp, pressure, status);
    seq++;
    nanosleep(&period, NULL);
  }
  return 0;
}

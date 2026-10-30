package com.example.busbooking.entity;

public enum BusType {
    AC_SEATER, NON_AC_SEATER, AC_SLEEPER, NON_AC_SLEEPER;

    public boolean isSleeper() {
        return this == AC_SLEEPER || this == NON_AC_SLEEPER;
    }
}

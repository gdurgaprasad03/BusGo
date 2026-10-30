package com.example.busbooking.mail;

import com.example.busbooking.dto.BookingResponse;

import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.stream.Collectors;

/** The wording of every email. Plain text, so it displays the same everywhere. */
public final class EmailTemplates {

    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("EEE, d MMM yyyy, hh:mm a", Locale.ENGLISH);
    private static final String FOOTER = "\n\n-- \nBusGo (demo application). Bus data is sample data and payments are simulated.";

    private EmailTemplates() {
    }

    public static OutgoingEmail welcome(String to, String name) {
        return new OutgoingEmail(to, "Welcome to BusGo",
                "Hi " + name + ",\n\nYour BusGo account is ready. You can now search buses, pick seats and manage your bookings."
                        + "\n\nIf you did not create this account, you can ignore this email." + FOOTER);
    }

    public static OutgoingEmail resetCode(String to, String name, String code, int minutes) {
        return new OutgoingEmail(to, "Your BusGo password reset code",
                "Hi " + name + ",\n\nYour password reset code is:\n\n    " + code + "\n\nIt works once and expires in "
                        + minutes + " minutes. Never share it with anyone."
                        + "\n\nIf you did not ask to reset your password, ignore this email: your password has not changed." + FOOTER);
    }

    public static OutgoingEmail passwordChanged(String to, String name) {
        return new OutgoingEmail(to, "Your BusGo password was changed",
                "Hi " + name + ",\n\nThe password for your BusGo account was just changed."
                        + "\n\nIf this was not you, reset your password again straight away." + FOOTER);
    }

    public static OutgoingEmail bookingConfirmed(String to, BookingResponse b) {
        return new OutgoingEmail(to, "BusGo booking confirmed: " + b.bookingReference(),
                "Your booking is confirmed.\n\n" + summary(b)
                        + "\n\nOpen the BusGo app > My Bookings to see your ticket or download it as a PDF."
                        + "\nThis is a DEMO booking: it cannot be used to travel." + FOOTER);
    }

    public static OutgoingEmail bookingCancelled(String to, BookingResponse b) {
        return new OutgoingEmail(to, "BusGo booking cancelled: " + b.bookingReference(),
                "Your booking has been cancelled.\n\n" + summary(b)
                        + "\n\nDemo refund: Rs " + b.refundAmount() + " (simulated, no money moves)." + FOOTER);
    }

    private static String summary(BookingResponse b) {
        String passengers = b.passengers().stream()
                .map(p -> p.name() + " (seat " + p.seatNumber() + ")")
                .collect(Collectors.joining(", "));
        return "Booking ID : " + b.bookingReference()
                + "\nRoute      : " + b.source() + " to " + b.destination()
                + "\nOperator   : " + b.operatorName() + " (" + b.busType().replace('_', ' ') + ")"
                + "\nDeparture  : " + b.departureTime().format(WHEN) + " from " + b.boardingPoint()
                + "\nArrival    : " + b.arrivalTime().format(WHEN) + " at " + b.droppingPoint()
                + "\nPassengers : " + passengers
                + "\nTotal fare : Rs " + b.totalAmount();
    }
}

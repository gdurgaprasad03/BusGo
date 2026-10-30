package com.example.busbooking.mail;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Queues an email from inside a service method. The email is handed to {@link MailService} only AFTER the database
 * transaction commits, so nobody receives "booking confirmed" for a booking that was rolled back.
 */
@Component
public class Mailer {

    private final ApplicationEventPublisher events;
    private final MailService mailService;

    public Mailer(ApplicationEventPublisher events, MailService mailService) {
        this.events = events;
        this.mailService = mailService;
    }

    public void queue(OutgoingEmail email) {
        if (email.to() == null || email.to().isBlank()) {
            return;
        }
        events.publishEvent(email);
    }

    public boolean isDeliveryEnabled() {
        return mailService.isDeliveryEnabled();
    }

    // fallbackExecution = true: also deliver when there is no transaction at all.
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    void onCommitted(OutgoingEmail email) {
        mailService.send(email);
    }
}

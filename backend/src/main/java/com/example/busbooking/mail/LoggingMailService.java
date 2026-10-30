package com.example.busbooking.mail;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Service;

/**
 * Used when email is NOT configured. Nothing is sent. It only writes a log line so developers can see what would
 * have been sent. Message bodies (which contain reset codes) are logged only if app.mail.log-bodies=true, a
 * development switch that must stay off anywhere real users exist.
 */
@Service
@ConditionalOnExpression("'${app.mail.enabled:false}' != 'true'")
public class LoggingMailService implements MailService {

    private static final Logger log = LoggerFactory.getLogger(LoggingMailService.class);

    private final boolean logBodies;

    public LoggingMailService(@Value("${app.mail.log-bodies:false}") boolean logBodies) {
        this.logBodies = logBodies;
        log.warn("Email is NOT configured (app.mail.enabled=false): no email will be sent. See docs/EMAIL_SETUP.md.");
    }

    @Override
    public boolean isDeliveryEnabled() {
        return false;
    }

    @Override
    public void send(OutgoingEmail email) {
        if (logBodies) {
            log.info("[mail disabled] would send to {} | {}\n{}", SmtpMailService.mask(email.to()), email.subject(), email.body());
        } else {
            log.info("[mail disabled] would send '{}' to {}", email.subject(), SmtpMailService.mask(email.to()));
        }
    }
}

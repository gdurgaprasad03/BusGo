package com.example.busbooking.dto;

/** One place in the autocomplete list. {@code hasService} = at least one demo route starts or ends here. */
public record PlaceResponse(String name, String state, boolean hasService) {
}

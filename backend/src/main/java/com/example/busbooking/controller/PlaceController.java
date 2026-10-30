package com.example.busbooking.controller;

import com.example.busbooking.dto.PlaceResponse;
import com.example.busbooking.dto.StateResponse;
import com.example.busbooking.service.PlaceService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Place autocomplete for the From / To pickers. Public (no login needed), like trip search. */
@RestController
@RequestMapping("/api/places")
public class PlaceController {

    private final PlaceService placeService;

    public PlaceController(PlaceService placeService) {
        this.placeService = placeService;
    }

    /** GET /api/places?query=kur&state=Andhra%20Pradesh&limit=20 */
    @GetMapping
    public List<PlaceResponse> search(@RequestParam(defaultValue = "") String query,
                                      @RequestParam(required = false) String state,
                                      @RequestParam(defaultValue = "20") int limit) {
        return placeService.search(query, state, limit);
    }

    /** GET /api/places/states: the 28 states and 8 union territories. */
    @GetMapping("/states")
    public List<StateResponse> states() {
        return placeService.states();
    }
}

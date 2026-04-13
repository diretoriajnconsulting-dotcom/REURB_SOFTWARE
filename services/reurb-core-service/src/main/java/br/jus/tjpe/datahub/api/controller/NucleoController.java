package br.jus.tjpe.datahub.api.controller;

import br.jus.tjpe.datahub.api.dto.NucleoRequest;
import br.jus.tjpe.datahub.api.dto.NucleoResponse;
import br.jus.tjpe.datahub.api.dto.StatusTransitionRequest;
import br.jus.tjpe.datahub.domain.model.StatusNucleo;
import br.jus.tjpe.datahub.domain.service.NucleoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/nucleos")
@RequiredArgsConstructor
@Tag(name = "Nucleos REURB", description = "Gestao do ciclo de vida dos nucleos de regularizacao fundiaria")
public class NucleoController {

    private final NucleoService nucleoService;

    @PostMapping
    @Operation(summary = "Criar novo nucleo REURB")
    public ResponseEntity<NucleoResponse> criar(@Valid @RequestBody NucleoRequest request) {
        var response = nucleoService.criar(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Buscar nucleo por ID")
    public ResponseEntity<NucleoResponse> buscarPorId(@PathVariable UUID id) {
        return ResponseEntity.ok(nucleoService.buscarPorId(id));
    }

    @GetMapping
    @Operation(summary = "Listar nucleos com filtros opcionais")
    public ResponseEntity<Page<NucleoResponse>> listar(
            @RequestParam(required = false) Integer municipio,
            @RequestParam(required = false) StatusNucleo status,
            Pageable pageable) {
        return ResponseEntity.ok(nucleoService.listar(municipio, status, pageable));
    }

    @PutMapping("/{id}/status")
    @Operation(summary = "Transicionar status do nucleo (maquina de estados)")
    public ResponseEntity<NucleoResponse> transicionarStatus(
            @PathVariable UUID id,
            @Valid @RequestBody StatusTransitionRequest request) {
        return ResponseEntity.ok(nucleoService.transicionarStatus(id, request));
    }
}

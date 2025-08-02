<?php

namespace App\Models;

class PayerConflictPractice
{
    protected $payerId;
    protected $crDateUnique;
    protected $conType;
    protected $conTypes;
    protected $costType;
    protected $visitType;
    protected $statusFlag;
    protected $coTo;
    protected $coSp;
    protected $coOp;
    protected $coFp;

    public function __construct(array $data = [])
    {
        $this->payerId = $data['PAYERID'] ?? null;
        $this->crDateUnique = $data['CRDATEUNIQUE'] ?? null;
        $this->conType = $data['CONTYPE'] ?? null;
        $this->conTypes = $data['CONTYPES'] ?? null;
        $this->costType = $data['COSTTYPE'] ?? null;
        $this->visitType = $data['VISITTYPE'] ?? null;
        $this->statusFlag = $data['STATUSFLAG'] ?? null;
        $this->coTo = $data['CO_TO'] ?? null;
        $this->coSp = $data['CO_SP'] ?? null;
        $this->coOp = $data['CO_OP'] ?? null;
        $this->coFp = $data['CO_FP'] ?? null;
    }

    public function getPayerId(): ?string
    {
        return $this->payerId;
    }

    public function setPayerId(?string $payerId): void
    {
        $this->payerId = $payerId;
    }

    public function getCrDateUnique(): ?string
    {
        return $this->crDateUnique;
    }

    public function setCrDateUnique(?string $crDateUnique): void
    {
        $this->crDateUnique = $crDateUnique;
    }

    public function getConType(): ?string
    {
        return $this->conType;
    }

    public function setConType(?string $conType): void
    {
        $this->conType = $conType;
    }

    public function getConTypes(): ?string
    {
        return $this->conTypes;
    }

    public function setConTypes(?string $conTypes): void
    {
        $this->conTypes = $conTypes;
    }

    public function getCostType(): ?string
    {
        return $this->costType;
    }

    public function setCostType(?string $costType): void
    {
        $this->costType = $costType;
    }

    public function getVisitType(): ?string
    {
        return $this->visitType;
    }

    public function setVisitType(?string $visitType): void
    {
        $this->visitType = $visitType;
    }

    public function getStatusFlag(): ?string
    {
        return $this->statusFlag;
    }

    public function setStatusFlag(?string $statusFlag): void
    {
        $this->statusFlag = $statusFlag;
    }

    public function getCoTo(): ?int
    {
        return $this->coTo;
    }

    public function setCoTo(?int $coTo): void
    {
        $this->coTo = $coTo;
    }

    public function getCoSp(): ?float
    {
        return $this->coSp;
    }

    public function setCoSp(?float $coSp): void
    {
        $this->coSp = $coSp;
    }

    public function getCoOp(): ?float
    {
        return $this->coOp;
    }

    public function setCoOp(?float $coOp): void
    {
        $this->coOp = $coOp;
    }

    public function getCoFp(): ?float
    {
        return $this->coFp;
    }

    public function setCoFp(?float $coFp): void
    {
        $this->coFp = $coFp;
    }

    public function toArray(): array
    {
        return [
            'PAYERID' => $this->payerId,
            'CRDATEUNIQUE' => $this->crDateUnique,
            'CONTYPE' => $this->conType,
            'CONTYPES' => $this->conTypes,
            'COSTTYPE' => $this->costType,
            'VISITTYPE' => $this->visitType,
            'STATUSFLAG' => $this->statusFlag,
            'CO_TO' => $this->coTo,
            'CO_SP' => $this->coSp,
            'CO_OP' => $this->coOp,
            'CO_FP' => $this->coFp,
        ];
    }
} 
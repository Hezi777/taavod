"use client";

import { useState } from "react";
import Link from "next/link";
import { Check, ChevronDown, Loader2, RefreshCw, Sparkles, Zap } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { useCareer } from "@/lib/career-store";

type Provider = "anthropic" | "groq";
type Model = { id: string; name?: string };
const providers = [{ id: "anthropic" as const, name: "Claude", Icon: Sparkles }, { id: "groq" as const, name: "Groq", Icon: Zap }];

export function CoachModelPicker({ provider, model, disabled, onChange }: { provider: Provider; model?: string; disabled?: boolean; onChange: (provider: Provider, model?: string) => void }) {
  const { integrations } = useCareer();
  const [models, setModels] = useState<Partial<Record<Provider, Model[]>>>({});
  const [loading, setLoading] = useState<Partial<Record<Provider, boolean>>>({});
  const [errors, setErrors] = useState<Partial<Record<Provider, string>>>({});
  const integration = integrations.find(item => item.provider === provider);
  const selected = model || integration?.model;
  const selectedModel = models[provider]?.find(item => item.id === selected);
  const selectedProvider = providers.find(item => item.id === provider)!;

  async function load(next: Provider) {
    if (loading[next]) return;
    setLoading(current => ({ ...current, [next]: true }));
    setErrors(current => ({ ...current, [next]: "" }));
    try {
      const response = await fetch(`/api/integrations/${next}/models`);
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || "Could not load models.");
      const options: Model[] = (result.models || []).map((item: string | Model) => typeof item === "string" ? { id: item } : item);
      setModels(current => ({ ...current, [next]: options }));
    } catch (error) {
      setErrors(current => ({ ...current, [next]: error instanceof Error ? error.message : "Could not load models." }));
    } finally {
      setLoading(current => ({ ...current, [next]: false }));
    }
  }

  return <DropdownMenu onOpenChange={open => {
    if (open) for (const item of providers) if (integrations.some(saved => saved.provider === item.id && saved.configured) && !models[item.id] && !loading[item.id]) void load(item.id);
  }}>
    <DropdownMenuTrigger asChild><Button type="button" variant="ghost" className="coach-model-trigger" disabled={disabled} aria-label={`Choose AI model. Current: ${selectedProvider.name}${selected ? ` ${selectedModel?.name || selected}` : " default"}`}><selectedProvider.Icon size={14} /><span>{selectedModel?.name || (selected ? `${selectedProvider.name} · ${selected}` : selectedProvider.name)}</span><ChevronDown size={12} /></Button></DropdownMenuTrigger>
    <DropdownMenuContent className="coach-model-menu" align="start" side="top" sideOffset={10}>
      <DropdownMenuLabel>Choose your thinking partner</DropdownMenuLabel>
      {providers.map(item => {
        const saved = integrations.find(integration => integration.provider === item.id);
        const activeModel = provider === item.id ? selected : undefined;
        return <div key={item.id}>
          <DropdownMenuSeparator />
          <DropdownMenuLabel className="coach-provider-label"><item.Icon size={14} />{item.name}<small>{saved?.configured ? "Connected" : "Not connected"}</small></DropdownMenuLabel>
          {!saved?.configured ? <><DropdownMenuItem onSelect={() => onChange(item.id)}><span>Use {item.name}</span>{provider === item.id && <Check size={14} />}</DropdownMenuItem><DropdownMenuItem asChild><Link href="/settings#integrations">Connect {item.name} in Settings</Link></DropdownMenuItem></> : <>
            {loading[item.id] && <div className="coach-model-status" role="status"><Loader2 size={14} className="animate-spin" />Loading available models…</div>}
            {errors[item.id] && <div className="coach-model-status" role="alert"><p>{errors[item.id]}</p><Button type="button" variant="ghost" size="sm" onClick={() => void load(item.id)}><RefreshCw size={13} />Try again</Button></div>}
            {models[item.id]?.map(option => <DropdownMenuItem key={option.id} className="coach-model-option" onSelect={() => onChange(item.id, option.id)}><span><strong>{option.name || option.id}</strong>{option.name && <small>{option.id}</small>}</span>{activeModel === option.id && <Check size={14} />}</DropdownMenuItem>)}
            {models[item.id]?.length === 0 && <div className="coach-model-status">No models are available for this key.</div>}
            {models[item.id] && saved.model && !models[item.id]?.some(option => option.id === saved.model) && <p className="coach-model-status">Your saved model is not in the current list. Choose an available model above.</p>}
          </>}
        </div>;
      })}
      <DropdownMenuSeparator /><p className="coach-model-footnote">Available models come directly from your connected providers.</p>
    </DropdownMenuContent>
  </DropdownMenu>;
}

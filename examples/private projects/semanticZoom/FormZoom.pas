unit FormZoom;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormZoom — Semantic Zoom demo for Home Assist Secure
//
//  Loads has-zoom.json via the lynkfs CDN and renders it in TZoomSurface.
//  The surface fills the viewport; no chrome, no toolbar.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JSemanticZoom;

type
  TFormZoom = class(TW3Form)
  private
    FSurface: TZoomSurface;
    procedure BuildContent;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, JToast, HttpClient;

{ TFormZoom }

procedure TFormZoom.BuildContent;
begin
  FetchJSON('has-zoom.json',
    procedure(Data: variant)
    begin
      FSurface.LoadFromObject(Data);
      FSurface.ZoomTo('overview');
      FSurface.PulseValue('Privacy');
    end,
    procedure(Status: Integer; Msg: String)
    begin
      Toast('Could not load content (' + IntToStr(Status) + '): ' + Msg,
            ttDanger, 6000);
    end);
end;

procedure TFormZoom.InitializeObject;
begin
  Inherited;

  SetStyle('position',   'relative');
  SetStyle('background', 'transparent');
  SetStyle('overflow',   'hidden');

  FSurface := TZoomSurface.Create(Self);

  FSurface.OnExamine := lambda FSurface.ZoomTo('summary'); end;

  FSurface.OnFormSubmit := procedure(Sender: TObject; Key: String; Values: variant)
  var
    v:       variant;
    concern: String;
  begin
    asm
      var vv = (@Values).concern;
      @concern = (vv !== undefined && vv !== null) ? String(vv).trim() : '';
    end;
    if concern = '' then
      Toast('Please describe your concern before submitting.', ttWarning, 3000)
    else
    begin
      Toast('Concern flagged: ' + concern, ttInfo, 4000);
      FSurface.ZoomOut;
    end;
  end;

  BuildContent;
end;

end.

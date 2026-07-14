using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;

namespace Myco.Views;

public partial class HomeView : UserControl
{
    public HomeView()
    {
        InitializeComponent();
        AppStore.I.StateChanged += () => Dispatcher.Invoke(Rebuild);
        Theme.Changed += () => Dispatcher.Invoke(Rebuild);   // Badge/CountBrush 需按新主题重算
        Rebuild();
    }

    private void Rebuild()
    {
        var s = AppStore.I;

        StatAgents.Text = s.InstalledCount.ToString();
        StatSessions.Text = s.TotalSessions.ToString();
        HeroSub.Text = $"跨 {s.InstalledCount} 个 agent · 可归档与接力";
        StatSkills.Text = s.Skills.Count.ToString();

        AgentsList.ItemsSource = null;
        AgentsList.ItemsSource = s.Agents;
    }

    private void OnGoShare(object sender, System.Windows.RoutedEventArgs e) => AppStore.I.SetTab("share");
    private void OnGoRelay(object sender, System.Windows.RoutedEventArgs e) => AppStore.I.SetTab("relay");
}
